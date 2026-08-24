# frozen_string_literal: true

# Общие параметры игры eraofchange. Год/расписание пишет eraofchange —
# era_mobile_api только читает их и инкрементит счётчики караванов (как eraofchange).
class Shared::GameParameter < ApplicationRecord
  self.table_name = "game_parameters"

  def self.current_year
    find_by(identificator: "current_year")&.value.to_i
  end

  def self.years_count
    find_by(identificator: "years_count")&.value.to_i
  end

  def self.schedule_items
    gp = find_by(identificator: "schedule")
    (gp&.params).presence || default_schedule_fallback
  end

  def self.default_schedule_fallback
    [
      { "id" => 3, "identificator" => "Первый цикл", "start" => "11:30", "finish" => "13:00", "type" => "play" },
      { "id" => 4, "identificator" => "Второй цикл", "start" => "13:00", "finish" => "14:00", "type" => "play" },
      { "id" => 6, "identificator" => "Третий цикл", "start" => "14:30", "finish" => "15:30", "type" => "play" },
      { "id" => 7, "identificator" => "Четвертый цикл", "start" => "15:30", "finish" => "16:30", "type" => "play" },
      { "id" => 8, "identificator" => "Пятый цикл", "start" => "16:30", "finish" => "17:30", "type" => "play" }
    ]
  end

  # Текущая позиция расписания + остаток секунд цикла (шапка лобби, FR-6)
  def self.cycle_state(now = Time.current)
    items = schedule_items.select { |i| i["type"] == "play" }
    item = items.find do |i|
      t0 = Time.zone.parse("#{Date.current} #{i['start']}")
      t1 = Time.zone.parse("#{Date.current} #{i['finish']}")
      t0 && t1 && now.between?(t0, t1)
    end
    return { year: current_year, cycle_item: nil, seconds_left: nil } if item.nil?

    finish = Time.zone.parse("#{Date.current} #{item['finish']}")
    { year: current_year, cycle_item: item, seconds_left: [0, (finish - now).to_i].max }
  end

  # ─── Настройки ограбления (caravan_robbery_settings) ──────────────────────
  ROBBERY_GP_ID = "caravan_robbery_settings"

  def self.robbery_param(key)
    find_by(identificator: ROBBERY_GP_ID)&.params&.dig(key) || {}
  end

  def self.get_robbery_count_for_year(year)
    robbery_param("robbery_by_year")[year.to_s].to_i
  end

  def self.get_arrived_count_for_year(year)
    robbery_param("arrived_count_by_year")[year.to_s].to_i
  end

  def self.get_robbed_count_for_year(year)
    robbery_param("robbed_count_by_year")[year.to_s].to_i
  end

  def self.increment_arrived_count(year)
    modify_robbery_hash("arrived_count_by_year", year, 1)
  end

  def self.increment_robbed_count(year)
    modify_robbery_hash("robbed_count_by_year", year, 1)
  end

  def self.modify_robbery_hash(param_key, year, delta)
    gp = find_by(identificator: ROBBERY_GP_ID)
    return unless gp
    p = gp.params || {}
    h = (p[param_key] || {})
    h[year.to_s] = h[year.to_s].to_i + delta
    p[param_key] = h
    gp.update!(params: p)
  end
end
