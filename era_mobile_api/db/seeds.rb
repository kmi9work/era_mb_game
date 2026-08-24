# frozen_string_literal: true

# Сид сценария «Эра перемен» (ТЗ раздел 12): перенос/переиспользование данных
# eraofchange/db/seeds. Общие справочники НЕ дублируются, если подключена общая БД —
# тогда заполняются только mb_scenario_configs и стартовые значения.
#
#   bundle exec rails db:seed

ActiveRecord::Base.transaction do
  # ─── Конфигурация сценария ─────────────────────────────────────────────────
  config = Mb::ScenarioConfig.find_or_create_by!(name: "Эра перемен") do |c|
    c.active = true
    c.settings = {
      "guild_owns_member_property" => true,
      "caravan_limit_per_country_year" => 1,
      "caravan_process_minutes" => 10,
      "caravan_price_fixing" => "processing",
      "trade_session_timeout_seconds" => 120,
      "starting_money" => 10_000,
      "dice_sides" => 20,
      "rebelling_region_ids" => []
    }
  end
  config.update!(active: true)

  # ─── Общие параметры игры (если песочница пустая) ──────────────────────────
  gp = Shared::GameParameter.find_by(identificator: "current_year")
  unless gp
    Shared::GameParameter.create!(
      name: "Текущий год", identificator: "current_year", value: "1", params: { "state_expenses" => false }
    )
  end

  unless Shared::GameParameter.find_by(identificator: "years_count")
    Shared::GameParameter.create!(name: "Количество лет", identificator: "years_count", value: "5", params: {})
  end

  unless Shared::GameParameter.find_by(identificator: "schedule")
    Shared::GameParameter.create!(
      name: "Расписание", identificator: "schedule", value: "1",
      params: [
        { "id" => 3, "identificator" => "Первый цикл", "start" => "11:30", "finish" => "13:00", "type" => "play" },
        { "id" => 4, "identificator" => "Второй цикл", "start" => "13:00", "finish" => "14:00", "type" => "play" },
        { "id" => 6, "identificator" => "Третий цикл", "start" => "14:30", "finish" => "15:30", "type" => "play" },
        { "id" => 7, "identificator" => "Четвертый цикл", "start" => "15:30", "finish" => "16:30", "type" => "play" },
        { "id" => 8, "identificator" => "Пятый цикл", "start" => "16:30", "finish" => "17:30", "type" => "play" }
      ]
    )
  end

  unless Shared::GameParameter.find_by(identificator: "caravans_per_guild")
    Shared::GameParameter.create!(name: "Количество караванов в гильдии",
                                  identificator: "caravans_per_guild", value: "3", params: {})
  end

  unless Shared::GameParameter.find_by(identificator: Shared::GameParameter::ROBBERY_GP_ID)
    Shared::GameParameter.create!(
      name: "Настройки ограбления караванов",
      identificator: Shared::GameParameter::ROBBERY_GP_ID,
      value: "0",
      params: {
        "robbery_by_year" => {}, "protected_guilds_by_year" => {},
        "arrived_count_by_year" => {}, "robbed_count_by_year" => {}
      }
    )
  end

  puts "Seeds: сценарий «Эра перемен» готов."
end
