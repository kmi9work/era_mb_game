# frozen_string_literal: true

# Единая точка работы с хранилищами имущества (ТЗ 6.3, 6.4).
# Все движения — в транзакции с блокировкой хранилищ; достаточность проверяется
# в момент коммита; каждое движение попадает в append-only журнал mb_operations.
class StorageService
  class InsufficientFunds < StandardError; end
  class MissingCard < StandardError; end

  MONEY_ID = "gold" # деньги — единый числовой баланс в ресурсе gold (ТЗ 6.2)

  ResourceRef = Struct.new(:type, :id, keyword_init: true)

  # ─── Чтение баланса хранилища ─────────────────────────────────────────────
  def self.balance(storage)
    items = Shared::ResourceItem.where(economic_subject_type: storage.type, economic_subject_id: storage.id)
    {
      money: items.find_by(identificator: MONEY_ID)&.count || 0,
      resources: items.where.not(identificator: MONEY_ID).order(:identificator).map do |ri|
        { identificator: ri.identificator, count: ri.count }
      end,
      cards: cards_json(Mb::Card.stock_of(owner_for(storage)))
    }
  end

  def self.cards_json(cards)
    cards.order(:created_at).map do |c|
      { id: c.id, kind: c.card_kind, name: c.display_name, year: c.obtained_year }
    end
  end

  def self.owner_for(storage)
    storage.type == "Guild" ? Shared::Guild.find(storage.id) : Shared::Player.find(storage.id)
  end

  def self.resource_name(identificator)
    @names ||= Shared::Resource.pluck(:identificator, :name).to_h
    @names[identificator] || (identificator == MONEY_ID ? "Золото" : identificator)
  end

  # ─── Перемещение позиций между двумя хранилищами одной транзакцией ────────
  # items: [{identificator:, name:, count:}] и/или [{is_card: true, card_id:, identificator:"card:<kind>", name:}]
  def self.transfer!(from:, to:, items:, kind:, initiator: nil, year: nil, ref: nil,
                     idempotency_key: nil, comment: nil, meta: {})
    if idempotency_key && (existing = find_applied(idempotency_key))
      return existing
    end

    ActiveRecord::Base.transaction do
      lock_storage(from)
      lock_storage(to)

      resource_items(items).each do |it|
        have = current_count(from, it[:identificator])
        if have < it[:count].to_i
          raise InsufficientFunds,
                "Недостаточно ресурсов #{resource_name(it[:identificator])} (требуется: #{it[:count]}, есть: #{have})"
        end
      end

      card_items(items).each do |ci|
        owner = owner_for(from)
        unless Mb::Card.stock_of(owner).where(id: ci[:card_id]).exists?
          raise MissingCard, "Нет карточки «#{ci[:name]}» в хранилище"
        end
      end

      op = create_operation(kind: kind, initiator: initiator, year: year, ref: ref,
                            idempotency_key: idempotency_key, comment: comment, meta: meta,
                            subject: from, counterparty: to)

      resource_items(items).each do |it|
        change_resource!(storage: from, identificator: it[:identificator], delta: -it[:count].to_i)
        change_resource!(storage: to, identificator: it[:identificator], delta: it[:count].to_i)
        op.operation_items.create!(identificator: it[:identificator], name: it[:name],
                                   delta: -it[:count].to_i)
        append_counterparty_meta(op, to, it)
      end

      card_items(items).each do |ci|
        card = Mb::Card.take_card!(owner: owner_for(from), kind: kind_of_card(ci), consumed_by: nil)
        Mb::Card.transaction do
          card.update!(owner_type: to.type, owner_id: to.id, status: :in_stock)
        end
        op.operation_items.create!(identificator: ci[:identificator], name: ci[:name],
                                   delta: 1, is_card: true, card_kind: kind_of_card(ci))
        append_counterparty_meta(op, to, identificator: ci[:identificator], count: 1)
      end

      op.update!(status: 1)
      op
    end
  end

  # Начисление/списание в одном хранилище (производство, покупка предприятия, коррекции мастера)
  # entries: [{identificator:, name:, delta:+/-}] / [{is_card:true, card_kind:, delta:+1|-1}]
  def self.adjust!(storage:, entries:, kind:, initiator: nil, year: nil, ref: nil,
                   idempotency_key: nil, comment: nil, meta: {})
    if idempotency_key && (existing = find_applied(idempotency_key))
      return existing
    end

    ActiveRecord::Base.transaction do
      lock_storage(storage)

      # Свернутые потребности по каждому ресурсу (несколько списаний в одной операции)
      needs = Hash.new(0)
      entries.reject { |e| e[:is_card] }.select { |e| e[:delta].to_i.negative? }.each do |e|
        needs[e[:identificator]] += e[:delta].to_i.abs
      end
      needs.each do |identificator, need|
        have = current_count(storage, identificator)
        if have < need
          raise InsufficientFunds,
                "Недостаточно ресурсов #{resource_name(identificator)} (требуется: #{need}, есть: #{have})"
        end
      end

      op = create_operation(kind: kind, initiator: initiator, year: year, ref: ref,
                            idempotency_key: idempotency_key, comment: comment, meta: meta,
                            subject: storage)

      entries.each do |e|
        delta = e[:delta].to_i
        next if delta.zero? && !e[:is_card]

        if e[:is_card]
          apply_card_delta!(owner: owner_for(storage), entry: e, op: op)
        else
          change_resource!(storage: storage, identificator: e[:identificator], delta: delta)
          op.operation_items.create!(identificator: e[:identificator], name: e[:name], delta: delta)
        end
      end

      op.update!(status: 1)
      op
    end
  end

  # ─── Внутреннее ────────────────────────────────────────────────────────────
  def self.find_applied(key)
    Mb::Operation.applied.find_by(idempotency_key: key)
  end

  def self.lock_storage(storage)
    storage.type == "Guild" ? Shared::Guild.lock.find(storage.id) : Shared::Player.lock.find(storage.id)
  end

  def self.current_count(storage, identificator)
    Shared::ResourceItem.where(economic_subject_type: storage.type, economic_subject_id: storage.id,
                               identificator: identificator).pick(:count) || 0
  end

  def self.change_resource!(storage:, identificator:, delta:)
    return if delta.zero?

    item = Shared::ResourceItem.lock.find_or_initialize_by(
      economic_subject_type: storage.type, economic_subject_id: storage.id, identificator: identificator
    )
    new_count = (item.count || 0) + delta
    raise InsufficientFunds, "Недостаточно ресурсов #{resource_name(identificator)}" if new_count.negative?

    if new_count.positive?
      item.count = new_count
      item.save!
    elsif item.persisted?
      item.destroy!
    end
  end

  def self.resource_items(items)
    items.reject { |i| i[:is_card] }
  end

  def self.card_items(items)
    items.select { |i| i[:is_card] }
  end

  def self.kind_of_card(card_item)
    card_item[:card_kind].presence ||
      card_item[:identificator].to_s.delete_prefix("card:").presence ||
      "unknown"
  end

  def self.apply_card_delta!(owner:, entry:, op:)
    delta = entry[:delta].to_i
    kind = entry[:card_kind].presence || entry[:identificator].to_s.delete_prefix("card:")
    if delta.positive?
      Mb::Card.create!(owner: owner, card_kind: kind, political_action_type_action: entry[:name],
                       obtained_year: op.year)
      op.operation_items.create!(identificator: entry[:identificator], name: entry[:name],
                                 delta: delta, is_card: true, card_kind: kind)
    elsif delta.negative?
      card = Mb::Card.stock_of(owner).lock.where(card_kind: kind).order(:created_at).first
      raise MissingCard, "Нет карточки «#{Mb::Card::CARD_KINDS[kind] || kind}»" unless card

      card.update!(status: :used, consumed_by_type: op.ref_type, consumed_by_id: op.ref_id)
      op.operation_items.create!(identificator: entry[:identificator], name: entry[:name],
                                 delta: delta, is_card: true, card_kind: kind)
    end
  end

  def self.append_counterparty_meta(op, storage, item)
    m = op.meta || {}
    key = "to_#{storage.type}_#{storage.id}"
    m[key] ||= []
    m[key] << { identificator: item[:identificator], count: item[:count].to_i }
    op.update_column(:meta, m)
  end

  def self.create_operation(kind:, initiator:, year:, ref:, idempotency_key:, comment:, meta:, subject:, counterparty: nil)
    Mb::Operation.create!(
      kind: kind,
      year: year || Shared::GameParameter.current_year,
      initiator: initiator,
      subject_type: subject.type, subject_id: subject.id,
      counterparty_type: counterparty&.type, counterparty_id: counterparty&.id,
      ref_type: ref&.class&.name, ref_id: ref&.id,
      idempotency_key: idempotency_key.presence || SecureRandom.uuid,
      comment: comment,
      meta: (meta || {}).stringify_keys,
      status: 0
    )
  end
end
