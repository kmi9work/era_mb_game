# frozen_string_literal: true

# FR-15: атомарное исполнение двусторонней сделки.
# Перемещает позиции между хранилищами сторон одной транзакцией,
# пишет операции в журнал обоим участникам, рассылает итоговые экраны.
class Mb::Trades::Execute
  Result = Struct.new(:error, :operations, keyword_init: true)

  def self.call!(session:)
    new(session).call!
  end

  def initialize(session)
    @session = session
  end

  def call!
    scenario = Mb::ScenarioConfig.current
    storage_a = storage_of(@session.initiator, scenario)
    storage_b = storage_of(@session.partner, scenario)
    offer_a = @session.offers_a
    offer_b = @session.offers_b
    year = Shared::GameParameter.current_year

    # Собираем единый список перемещений: A→B и B→A
    items_ab = build_items(offer_a)  # что отдаёт A
    items_ba = build_items(offer_b)  # что отдаёт B

    return Result.new(error: "Сделка пуста") if items_ab.empty? && items_ba.empty?

    op_a = nil
    op_b = nil

    ActiveRecord::Base.transaction do
      StorageService.lock_storage(storage_a)
      StorageService.lock_storage(storage_b)

      # Проверка достаточности у обеих сторон до движения (FR-15 атомарность)
      check_sufficiency!(storage_a, items_ab)
      check_sufficiency!(storage_b, items_ba)

      idem_a = "trade:#{@session.id}:a"
      idem_b = "trade:#{@session.id}:b"

      op_a = StorageService.transfer!(
        from: storage_a, to: storage_b, items: items_ab,
        kind: "trade", year: year, ref: @session,
        idempotency_key: idem_a,
        meta: { partner_player_id: @session.partner_id }
      )

      op_b = StorageService.transfer!(
        from: storage_b, to: storage_a, items: items_ba,
        kind: "trade", year: year, ref: @session,
        idempotency_key: idem_b,
        meta: { partner_player_id: @session.initiator_id }
      )

      @session.update!(status: :completed, completed_at: Time.current)
    end

    notify_participants(op_a, op_b)
    Result.new(error: nil, operations: [op_a, op_b].compact)
  rescue StorageService::InsufficientFunds, StorageService::MissingCard => e
    @session&.update_columns(confirmed_a: false, confirmed_b: false)
    Result.new(error: e.message)
  rescue ActiveRecord::RecordInvalid => e
    Result.new(error: e.message)
  end

  private

  def storage_of(player, scenario)
    player.effective_storage(scenario)
  end

  def build_items(offer)
    items = []
    money = offer["money"].to_i
    items << { identificator: StorageService::MONEY_ID, name: "Золото", count: money } if money.positive?

    Array(offer["resources"]).each do |r|
      count = r["count"].to_i
      next unless count.positive?
      items << { identificator: r["identificator"].to_s, name: r["name"].to_s, count: count }
    end

    Array(offer["cards"]).each do |card_id|
      card = Mb::Card.find_by(id: card_id)
      next if card.nil?
      items << { is_card: true, card_id: card.id, identificator: "card:#{card.card_kind}",
                 name: card.display_name }
    end

    items
  end

  def check_sufficiency!(storage, items)
    items.each do |it|
      if it[:is_card]
        owner = StorageService.owner_for(storage)
        raise StorageService::MissingCard, "Нет карточки «#{it[:name]}»" unless Mb::Card.stock_of(owner).where(id: it[:card_id]).exists?
      else
        have = StorageService.current_count(storage, it[:identificator])
        if have < it[:count]
          raise StorageService::InsufficientFunds,
                "Недостаточно ресурсов #{StorageService.resource_name(it[:identificator])} (требуется: #{it[:count]}, есть: #{have})"
        end
      end
    end
  end

  def notify_participants(op_a, op_b)
    [@session.initiator, @session.partner].each do |p|
      Mb::Notification.notify!(
        player: p,
        kind: "trade_completed",
        title: "Сделка исполнена",
        body: "Торговая сессия ##{@session.id} завершена",
        payload: { trade_session_id: @session.id },
        push: true
      )
    end
    CableBroadcast.trade_state(@session)
  rescue StandardError => e
    Rails.logger.warn("[Trade] notify failed: #{e.message}")
  end
end
