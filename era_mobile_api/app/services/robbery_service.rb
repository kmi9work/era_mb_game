# frozen_string_literal: true

# Ролл грабежа (Маст. Грабёж / FR-29): P = остаток_ограблений / остаток_караванов.
# Повторяет механику eraofchange RobberyService, но для мобильных заявок.
# Результат скрыт от игрока до момента обработки; мастер видит сразу.
class RobberyService
  ROBBERY_SUCCESS = :robbery_success
  ROBBERY_FAILURE = :robbery_failure
  NO_ROBBERY      = :no_robbery

  def self.attempt(year:, guild_id:, protected_flag: false)
    new(year, guild_id).attempt(protected_flag)
  end

  def self.probability_status(year:, guild_id:)
    new(year, guild_id).probability_status
  end

  def initialize(year, guild_id)
    @year = year
    @guild_id = guild_id
  end

  def attempt(protected_flag)
    return NO_ROBBERY if remained_caravans <= 0
    return NO_ROBBERY unless rand < robbery_probability

    Shared::GameParameter.increment_robbed_count(@year) # попытка потрачена
    return ROBBERY_FAILURE if guild_protected? || protected_flag
    ROBBERY_SUCCESS
  end

  def probability_status
    guild_protected? ? 0.0 : robbery_probability
  end

  def robbery_probability
    return 0.0 if total_caravans <= 0
    [remained_robberies.to_f / remained_caravans, 1.0].min
  end

  private

  def guild_protected?
    Shared::Guild.find_by(id: @guild_id)&.caravan_protected?(@year)
  end

  def remained_robberies
    Shared::GameParameter.get_robbery_count_for_year(@year)
  end

  def remained_caravans
    total_caravans - arrived_caravans
  end

  def total_caravans
    Shared::Guild.count * caravans_per_guild
  end

  def caravans_per_guild
    gp = Shared::GameParameter.find_by(identificator: "caravans_per_guild")
    gp&.value.to_i
  end

  def arrived_caravans
    Shared::GameParameter.get_arrived_count_for_year(@year)
  end
end
