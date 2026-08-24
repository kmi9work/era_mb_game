# frozen_string_literal: true

# Караваны мобильной игры (FR-25..FR-31).
class CaravanService
  class RuleError < StandardError; end

  Result = Struct.new(:ok, :error, :caravan, keyword_init: true)

  # ─── FR-25: страны с отношениями и ценами ──────────────────────────────────
  def self.countries_view
    Shared::Country.order(:id).map do |c|
      {
        id: c.id,
        name: c.name,
        relations: c.relations,
        embargo: c.embargo?,
        prices: c.trade_prices
      }
    end
  end

  # ─── FR-25/FR-26: список своих караванов + остаток на год ──────────────────
  def self.list(player:, scenario:)
    storage = player.effective_storage(scenario)
    guild_id = storage.type == "Guild" ? storage.id : player.guild_id
    year = Shared::GameParameter.current_year
    limit = scenario.setting("caravan_limit_per_country_year")

    countries_used = Mb::CaravanMobile.for_guild_year(guild_id, year)
                                      .where.not(status: :cancelled_by_master)
                                      .pluck(:country_id)

    view = Mb::CaravanMobile.for_guild_year(guild_id, year).order(sent_at: :desc).map { |c| caravan_json(c, public: true) }

    {
      caravans: view,
      year: year,
      countries_available: Shared::Country.where.not(id: countries_used).order(:id).pluck(:id),
      limit_per_country: limit
    }
  end

  def self.caravan_json(c, public: false)
    base = {
      id: c.id, country_id: c.country_id, country: c.country.name, status: c.status,
      sent_at: c.sent_at, process_at: c.process_at,
      sell_items: c.sell_items, buy_items: c.buy_items,
      sale_income: c.sale_income, purchase_cost: c.purchase_cost
    }
    unless public
      base[:roll_probability] = c.roll_probability
      base[:precalculated_robbed] = c.precalculated_robbed
    end
    base[:processed_at] = c.processed_at unless c.in_transit?
    base
  end

  # ─── FR-25..FR-28: отправка заявки ─────────────────────────────────────────
  def self.send!(player:, scenario:, country_id:, sell_items:, buy_items:, use_contraband:, idempotency_key:)
    year = Shared::GameParameter.current_year
    storage = player.effective_storage(scenario)
    raise RuleError, "Караваны отправляются от хранилища гильдии" unless storage.type == "Guild"
    guild = Shared::Guild.find(storage.id)
    country = Shared::Country.find(country_id)

    sell_items = normalize(sell_items)
    buy_items = normalize(buy_items)
    raise RuleError, "Корзина каравана пуста" if sell_items.empty? && buy_items.empty?

    # FR-26: лимит 1/год/страна — сервер (валидация уникальности в модели тоже)
    existing = Mb::CaravanMobile.for_guild_year(guild.id, year).where(country_id: country.id)
                                .where.not(status: :cancelled_by_master).exists?
    raise RuleError, "Караван в эту страну в этом году уже отправлен" if existing

    # FR-27: эмбарго и контрабанда
    contraband_card = nil
    if country.embargo?
      overseas = Shared::Technology.open?(Shared::Technology::OVERSEAS_TRADE)
      unless overseas || use_contraband
        raise RuleError, "На страну наложено эмбарго. Нужна карточка «Контрабанда»"
      end
      if use_contraband && !overseas
        owner = StorageService.owner_for(storage)
        contraband_card = Mb::Card.stock_of(owner).where(card_kind: "contraband").order(:created_at).first
        raise RuleError, "Нет карточки «Контрабанда» в казне гильдии" unless contraband_card
      end
    end

    # Проверка достаточности продаваемых позиций до списания
    check_availability!(storage, sell_items)

    # Предрасчёт исхода по ценам (базис фиксации — настройка сценария, раздел 17.1)
    basis = scenario.setting("caravan_price_fixing")
    amounts = precalculate(country, sell_items, buy_items, basis, year)

    minutes = scenario.setting("caravan_process_minutes").to_i
    now = Time.current

    caravan = nil
    ActiveRecord::Base.transaction do
      # Ролл грабежа в момент регистрации заявки (как в диздоке); исход скрыт от игрока
      protected_flag = guild.caravan_protected?(year)
      roll = RobberyService.attempt(year: year, guild_id: guild.id, protected_flag: protected_flag)
      robbed = roll == RobberyService::ROBBERY_SUCCESS

      Shared::GameParameter.increment_arrived_count(year)

      caravan = Mb::CaravanMobile.create!(
        guild_id: guild.id, country_id: country.id, year: year,
        status: :in_transit,
        sell_items: sell_items, buy_items: buy_items,
        sale_income: amounts[:sale_income], purchase_cost: amounts[:purchase_cost],
        price_basis_year: (basis == "sending" ? year : nil),
        roll_probability: RobberyService.probability_status(year: year, guild_id: guild.id),
        precalculated_robbed: robbed,
        contraband_used: contraband_card.present?,
        protected: protected_flag,
        sent_at: now, process_at: now + minutes.minutes
      )

      # Списание продаваемого сразу (имущество «уехало» с отправкой)
      entries = sell_items.map { |r| { identificator: r[:identificator], name: r[:name], delta: -r[:count].to_i } }
      if contraband_card
        entries << { is_card: true, card_kind: "contraband", identificator: "card:contraband",
                     name: "Контрабанда", delta: -1 }
      end

      StorageService.adjust!(
        storage: storage, entries: entries, kind: "caravan_send",
        initiator: player, ref: caravan,
        idempotency_key: idempotency_key.presence || SecureRandom.uuid,
        meta: { caravan_id: caravan.id }
      )
    end

    CaravanProcessJob.perform_later(caravan.id)
    Result.new(ok: true, caravan: caravan)
  rescue RuleError => e
    Result.new(ok: false, error: e.message)
  rescue ActiveRecord::RecordNotFound => e
    Result.new(ok: false, error: e.message)
  end

  # ─── FR-30: обработка заявки джобой ────────────────────────────────────────
  def self.process!(caravan, force_result: nil)
    return caravan unless caravan.in_transit?
    return caravan if caravan.process_at > Time.current && force_result.nil?

    scenario = Mb::ScenarioConfig.current
    storage = Shared::Guild.find(caravan.guild_id).storage
    year = caravan.year
    result = force_result || (caravan.precalculated_robbed? ? :robbed : :ok)

    ActiveRecord::Base.transaction do
      if result == :robbed
        caravan.update!(status: :robbed, processed_at: Time.current)
      else
        amounts = caravan.execution_amounts(prices_basis: scenario.setting("caravan_price_fixing"))
        entries = [{ identificator: StorageService::MONEY_ID, delta: amounts[:sale_income] - amounts[:purchase_cost] }]
        caravan.buy_items.each do |r|
          r = r.deep_symbolize_keys
          next if r[:identificator] == StorageService::MONEY_ID
          entries << { identificator: r[:identificator], name: r[:name], delta: r[:count].to_i }
        end

        op = StorageService.adjust!(
          storage: storage, entries: entries, kind: "caravan_result",
          ref: caravan,
          idempotency_key: "caravan_result:#{caravan.id}",
          comment: nil,
          meta: { caravan_id: caravan.id, amounts: amounts.as_json }
        )
        _ = op
        caravan.update!(status: :processed_ok, processed_at: Time.current)
      end
    end

    notify_players(caravan, result)
    caravan
  end

  # ─── helpers ───────────────────────────────────────────────────────────────
  def self.normalize(items)
    Array(items).map do |r|
      r = r.each_with_object({}) { |v, h| h[v[0].to_sym] = v[1] } if r.is_a?(Hash)
      { identificator: r[:identificator].to_s, name: r[:name].to_s, count: r[:count].to_i }
    end.select { |r| r[:count].positive? && r[:identificator].present? }
  end

  def self.check_availability!(storage, items)
    items.each do |r|
      have = StorageService.current_count(storage, r[:identificator])
      if have < r[:count].to_i
        raise RuleError, "Недостаточно ресурсов #{StorageService.resource_name(r[:identificator])} (требуется: #{r[:count]}, есть: #{have})"
      end
    end
  end

  def self.precompute_amounts(country, rel, items, side)
    items.sum do |r|
      res = Shared::Resource.find_by(identificator: r[:identificator])
      price = case side
              when :sale then res&.sale_price_for(rel)
              else res&.buy_price_for(rel)
              end
      (price || 0).to_i * r[:count].to_i
    end
  end

  def self.precalculate(country, sell_items, buy_items, basis, year)
    rel = country.relations
    amounts = {
      sale_income: precompute_amounts(country, rel, sell_items, :sale),
      purchase_cost: precompute_amounts(country, rel, buy_items, :buy)
    }
    amounts
  end

  def self.notify_players(caravan, result)
    players = Shared::Player.where(guild_id: caravan.guild_id)
    title = result == :robbed ? "Караван ограблен" : "Караван обработан"
    body = result == :robbed ? "Караван в #{caravan.country.name} потерян" : "Караван вернулся из #{caravan.country.name}"
    players.find_each do |p|
      Mb::Notification.notify!(player: p, kind: "caravan_processed", title: title, body: body,
                               payload: { caravan_id: caravan.id }, push: true)
    end
  rescue StandardError => e
    Rails.logger.warn("[Caravan] notify failed: #{e.message}")
  end
end
