# frozen_string_literal: true

class Shared::Plant < ApplicationRecord
  self.table_name = "plants"

  belongs_to :plant_level, optional: true, class_name: "Shared::PlantLevel"
  belongs_to :plant_place, optional: true, class_name: "Shared::PlantPlace"

  # Полиморфный владелец; в БД типы хранятся как "Guild"/"Player" (как eraofchange).
  # Резолвим в Shared::* модели вручную, чтобы не зависеть от глобальных констант.
  def economic_subject
    case economic_subject_type
    when "Guild" then Shared::Guild.find_by(id: economic_subject_id)
    when "Player" then Shared::Player.find_by(id: economic_subject_id)
    end
  end

  scope :of_owner, ->(type, id) { where(economic_subject_type: type, economic_subject_id: id) }

  def produced_years
    params&.dig("produced") || []
  end

  def produced_this_year?(year)
    produced_years.include?(year)
  end

  def mark_produced!(year)
    self.params = (params || {}).merge("produced" => (produced_years + [year]).uniq)
    save!
  end
end
