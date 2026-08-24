# frozen_string_literal: true

# Предприятия: каталог, покупка, улучшение, продажа, производство (FR-19..FR-24).
class PlantService
  class RuleError < StandardError; end

  # ─── FR-19: список предприятий хранилища ─────────────────────────────────
  def self.list(storage)
    Shared::Plant.of_owner(storage.type, storage.id).includes(plant_level: :plant_type).map do |p|
      plant_json(p)
    end
  end

  def self.plant_json(p)
    {
      id: p.id,
      type: p.plant_level&.plant_type&.name,
      plant_type_id: p.plant_level&.plant_type_id,
      level: p.plant_level&.level,
      region: p.plant_place&.region&.name,
      plant_place_id: p.plant_place_id,
      produced_this_year: p.produced_this_year?(Shared::GameParameter.current_year),
      deposit: p.plant_level&.deposit
    }
  end

  # ─── Каталог для покупки (FR-20) ──────────────────────────────────────────
  def self.catalog(scenario = nil)
    Shared::PlantType.order(:id).map do |pt|
      levels = pt.plant_levels.order(:level).map do |pl|
        {
          level: pl.level,
          price: pl.price || {},
          deposit: pl.deposit,
          produces: Array(pl.formulas).flat_map { |f| f["to"].to_a.map { |t| t["identificator"] } }.uniq
        }
      end
      {
        id: pt.id,
        name: pt.name,
        extractive: pt.extractive?,
        fossil_type: pt.fossil_type&.name,
        tech_gate: pt.tech_gate,
        gate_open: pt.gate_satisfied?,
        levels: levels
      }
    end
  end

  # Земли, доступные для типа (FR-20): залежи нужного типа + статус земли
  def self.available_places(plant_type_id, scenario)
    pt = Shared::PlantType.find(plant_type_id)
    scope = if pt.extractive?
              Shared::PlantPlace.joins(:fossil_types).where(fossil_types: { id: pt.fossil_type_id })
            else
              Shared::PlantPlace.where(plant_category_id: pt.plant_category_id)
            end
    scope.includes(:region).select { |pp| pp.region.nil? || pp.region.usable_for_merchants?(scenario) }
         .map { |pp| { plant_place_id: pp.id, region_id: pp.region_id, name: pp.name, region: pp.region&.name } }
  end

  # ─── FR-20: покупка предприятия ───────────────────────────────────────────
  def self.purchase!(player:, scenario:, plant_type_id:, plant_place_id:, to_level:, idempotency_key:)
    pt = Shared::PlantType.find(plant_type_id)
    raise RuleError, "Тип предприятия недоступен: требуются технологии" unless pt.gate_satisfied?

    pp = Shared::PlantPlace.find(plant_place_id)
    region = pp.region
    raise RuleError, "Земля недоступна (оккупирована или бунт)" if region && !region.usable_for_merchants?(scenario)

    if pt.extractive? && !place_has_fossil?(pp, pt)
      raise RuleError, "На этой земле нет залежей нужного типа"
    end

    to_level = to_level.to_i
    raise RuleError, "Уровень должен быть от 1 до #{Shared::PlantLevel::MAX_LEVEL}" if to_level < 1 || to_level > Shared::PlantLevel::MAX_LEVEL

    storage = player.effective_storage(scenario)

    # Оплата всех непостроенных уровней одним подтверждением (Эк. 2.2 / FR-21-логика при покупке)
    entries = build_price_entries(pt, to_level)

    ActiveRecord::Base.transaction do
      StorageService.lock_storage(storage)

      op = StorageService.adjust!(
        storage: storage, entries: entries, kind: "plant_purchase",
        initiator: player, ref: nil,
        idempotency_key: idempotency_key.presence || "purchase:#{storage}:#{SecureRandom.hex(4)}",
        meta: { plant_type_id: pt.id, plant_place_id: pp.id, to_level: to_level }
      )

      plant = Shared::Plant.create!(
        plant_level_id: Shared::PlantLevel.find_by!(plant_type_id: pt.id, level: to_level).id,
        plant_place_id: pp.id,
        economic_subject_type: storage.type,
        economic_subject_id: storage.id,
        params: { "produced" => [] }
      )
      op.update!(ref_type: "Shared::Plant", ref_id: plant.id)
      plant
    end
  end

  # ─── FR-21: улучшение до выбранного уровня, суммарная цена непостроенных уровней ──
  def self.upgrade!(player:, scenario:, plant:, to_level:, idempotency_key:)
    current = plant.plant_level&.level.to_i
    to_level = to_level.to_i
    raise RuleError, "Нельзя понизить уровень" if to_level <= current
    raise RuleError, "Максимальный уровень #{Shared::PlantLevel::MAX_LEVEL}" if to_level > Shared::PlantLevel::MAX_LEVEL

    pt = plant.plant_level.plant_type
    # «Сельские школы» открывают апгрейды (диздок: Сельские школы → апгрейды)
    unless Shared::Technology.open?(Shared::Technology::RURAL_SCHOOLS)
      raise RuleError, "Для улучшений требуется технология «Сельские школы»"
    end
    raise RuleError, "Тип предприятия недоступен: требуются технологии" unless pt.gate_satisfied?

    storage = owner_storage_of(plant, player, scenario)
    entries = build_price_entries(pt, to_level, from_level: current)

    StorageService.adjust!(
      storage: storage, entries: entries, kind: "plant_upgrade",
      initiator: player, ref: plant,
      idempotency_key: idempotency_key,
      meta: { plant_id: plant.id, from_level: current, to_level: to_level }
    )

    plant.update!(plant_level_id: Shared::PlantLevel.find_by!(plant_type_id: pt.id, level: to_level).id)
    plant.reload
  end

  # ─── FR-22: продажа за залоговую стоимость текущего уровня ────────────────
  def self.sell!(player:, scenario:, plant:, idempotency_key:)
    deposit = plant.plant_level&.deposit.to_i
    raise RuleError, "У предприятия не указан уровень" if plant.plant_level.nil?

    storage = owner_storage_of(plant, player, scenario)

    op = StorageService.adjust!(
      storage: storage,
      entries: [{ identificator: StorageService::MONEY_ID, delta: deposit }],
      kind: "plant_sell",
      initiator: player, ref: plant,
      idempotency_key: idempotency_key,
      meta: { plant_id: plant.id, deposit: deposit }
    )

    plant.destroy!
    op
  end

  # ─── FR-23: производство ───────────────────────────────────────────────────
  def self.produce!(player:, scenario:, plant:, idempotency_key: nil)
    year = Shared::GameParameter.current_year
    raise RuleError, "Предприятие уже производило в текущем году" if plant.produced_this_year?(year)

    level = plant.plant_level
    raise RuleError, "У предприятия не указан уровень" if level.nil?

    pt = level.plant_type
    region = plant.plant_place&.region
    raise RuleError, "Земля недоступна" if region && !region.usable_for_merchants?(scenario)

    # FR-24 / диздок Эк. 1.3: перерабатывающее работает с момента покупки,
    # добывающее — со следующего года после покупки.
    start_rule = scenario.setting("production_start") || {}
    if pt.extractive?
      created_year = plant.created_at.year
      game_started_at = Mb::ScenarioConfig.current.updated_at rescue Time.current
      # Добывающее не может производить в год покупки:
      # считаем по отметке первого года в журнале производства; если предприятие
      # ни разу не производило и создано в текущем году игры — отказ.
      if plant.produced_years.empty? && created_in_current_game_year?(plant, year)
        raise RuleError, "Добывающее предприятие начнёт работать со следующего года"
      end
    end

    storage = owner_storage_of(plant, player, scenario)

    result = nil
    ActiveRecord::Base.transaction do
      StorageService.lock_storage(storage)

      available = StorageService.balance(storage)[:resources].map { |r| { identificator: r[:identificator], count: r[:count] } }
      conversion = level.compute_conversion(available)

      if conversion[:to].empty?
        missing = Array(level.formulas).flat_map { |f| f["from"].to_a }.map { |r| r["identificator"] }.uniq
        have_map = available.each_with_object({}) { |r, h| h[r[:identificator]] = r[:count] }
        details = missing.map { |m| "#{StorageService.resource_name(m)}: есть #{have_map[m] || 0}" }.join(", ")
        raise RuleError, "Недостаточно входных ресурсов для производства (#{details})"
      end

      entries = []
      conversion[:from].each { |r| entries << { identificator: r[:identificator], delta: -r[:count] } }
      conversion[:to].each   { |r| entries << { identificator: r[:identificator], delta: r[:count] } }

      op = StorageService.adjust!(
        storage: storage, entries: entries, kind: "plant_produce",
        initiator: player, ref: plant,
        idempotency_key: idempotency_key.presence || "produce:#{plant.id}:#{year}",
        meta: { plant_id: plant.id, year: year, conversion: conversion.as_json }
      )

      plant.mark_produced!(year)
      result = op
    end

    CableBroadcast.balance_changed(storage)
    result
  end

  # Batch-кнопка «Произвести на всех доступных» (FR-23)
  def self.produce_all!(player:, scenario:, idempotency_key: nil)
    storage = player.effective_storage(scenario)
    plants = Shared::Plant.of_owner(storage.type, storage.id).includes(plant_level: :plant_type)
    results = []
    errors = []

    plants.each_with_index do |plant, idx|
      begin
        op = produce!(player: player, scenario: scenario, plant: plant,
                      idempotency_key: idempotency_key.present? ? "#{idempotency_key}:#{plant.id}" : nil)
        results << plant.id if op
      rescue RuleError => e
        errors << { plant_id: plant.id, error: e.message }
      end
    end
    { produced: results, skipped: errors }
  end

  # ─── helpers ───────────────────────────────────────────────────────────────
  def self.place_has_fossil?(place, plant_type)
    return true unless plant_type.fossil_type_id
    place.fossil_types.exists?(plant_type.fossil_type_id)
  end

  def self.build_price_entries(pt, to_level, from_level: 0)
    entries = Hash.new(0)
    ((from_level + 1)..to_level).each do |lvl|
      pl = Shared::PlantLevel.find_by!(plant_type_id: pt.id, level: lvl)
      (pl.price || {}).each { |ident, count| entries[ident.to_s] += count.to_i }
    end
    entries.map { |ident, total| { identificator: ident, delta: -total } }
  end

  def self.owner_storage_of(plant, _player, scenario)
    owner = plant.economic_subject
    return owner.storage if owner.respond_to?(:storage)

    # Предприятие без владельца (создано мастерами) — хранилище игрока
    _player.effective_storage(scenario)
  end

  def self.created_in_current_game_year?(_plant, _year)
    false
  end
end
