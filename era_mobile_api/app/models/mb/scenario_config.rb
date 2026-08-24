# frozen_string_literal: true

# Конфигурация сценария (раздел 12 ТЗ). Игра настраивается без изменения кода.
class Mb::ScenarioConfig < ApplicationRecord
  self.table_name = "mb_scenario_configs"

  validates :name, presence: true

  DEFAULTS = {
    "guild_owns_member_property" => true,
    "caravan_limit_per_country_year" => 1,
    "caravan_process_minutes" => 10,
    "caravan_price_fixing" => "processing", # processing | sending
    "trade_session_timeout_seconds" => 120,
    "starting_money" => 10_000,
    "dice_sides" => 20,
    "rebelling_region_ids" => [],
    "production_start" => { "extractive" => "next_year", "processing" => "immediately" } # FR-24 / диздок Эк. 1.3
  }.freeze

  def self.current
    where(active: true).order(:updated_at).first || new(name: "Эра перемен", settings: {})
  end

  def flag?(key)
    merged[key] == true
  end

  def setting(key)
    merged[key]
  end

  def merged
    DEFAULTS.merge(settings || {})
  end
end
