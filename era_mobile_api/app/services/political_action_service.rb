# frozen_string_literal: true

# Политические действия купцов (FR-32..FR-34): цена → бросок кубика d20 (RNG сервера)
# → успех: карточка действия в хранилище; провал: деньги списаны.
class PoliticalActionService
  class RuleError < StandardError; end

  Result = Struct.new(:ok, :error, :success, :roll, :card, keyword_init: true)

  # Список действий для главы гильдии
  def self.available(player:)
    Shared::PoliticalActionType.where(job_id: guild_boss_job_ids).map { |pat| pat_json(pat) }
  end

  def self.pat_json(pat)
    {
      id: pat.id,
      name: pat.name,
      action: pat.action,
      description: pat.description,
      cost: pat.cost.to_i,
      probability: pat.probability # "8-20" — порог кубика
    }
  end

  def self.perform!(player:, scenario:, political_action_type:, idempotency_key:)
    storage = player.effective_storage(scenario)

    cost = political_action_type.cost.to_i
    threshold = parse_threshold(political_action_type.probability) # минимальное значение кубика

    roll_result = nil
    card = nil

    ActiveRecord::Base.transaction do
      StorageService.lock_storage(storage)

      have = StorageService.current_count(storage, StorageService::MONEY_ID)
      if have < cost
        raise RuleError, "Недостаточно золота (требуется: #{cost}, есть: #{have})"
      end

      sides = scenario.setting("dice_sides") || 20
      roll = rand(1..sides)
      success = roll >= threshold

      entries = [{ identificator: StorageService::MONEY_ID, delta: -cost }]
      if success
        kind = auto_kind_for(political_action_type.action)
        entries << { identificator: "card:#{kind}", name: political_action_type.name,
                     delta: 1, is_card: true, card_kind: kind }
      end

      op = StorageService.adjust!(
        storage: storage, entries: entries, kind: "political_action",
        initiator: player, ref: nil,
        idempotency_key: idempotency_key.presence || SecureRandom.uuid,
        meta: { political_action_type_id: political_action_type.id, roll: roll, threshold: threshold,
                success: success }
      )

      roll_result = { roll: roll, threshold: threshold, success: success, operation_id: op.id }

      if success
        kind = auto_kind_for(political_action_type.action)
        card = Mb::Card.stock_of(StorageService.owner_for(storage)).where(card_kind: kind).order(:created_at).last
      end
    end

    Result.new(ok: true, error: nil, success: roll_result[:success], roll: roll_result, card: card)
  rescue RuleError => e
    Result.new(ok: false, error: e.message, success: nil, roll: nil, card: nil)
  end

  # Автоэффекты v1 (FR-34): только контрабанда и защита каравана автоматизированы.
  # Прочие карточки — предметы; их эффект активируют мастера вне приложения.
  def self.auto_kind_for(action)
    case action.to_s
    when "contraband" then "contraband"
    else "generic"
    end
  end

  def self.parse_threshold(probability_string)
    # "8-20" → 8; "-" → недоступно (максимум)
    s = probability_string.to_s.strip
    return 21 if s.empty? || s == "-"
    s.split("-").first.to_i
  end

  def self.guild_boss_job_ids
    [1] # Job::GUILD_BOSS «Глава гульдии» в eraofchange
  end
end
