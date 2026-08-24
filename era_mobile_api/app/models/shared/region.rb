# frozen_string_literal: true

class Shared::Region < ApplicationRecord
  self.table_name = "regions"

  belongs_to :country, class_name: "Shared::Country"
  has_many :plant_places, class_name: "Shared::PlantPlace"

  RUS_COUNTRY_ID = 1

  # Статусы земель (ТЗ раздел 12): оккупация = страна региона не Русь;
  # бунт — список регионов в конфиге сценария.
  def occupied?
    country_id != RUS_COUNTRY_ID
  end

  def rebelling?(scenario)
    ids = scenario&.settings&.dig("rebelling_region_ids") || []
    ids.map(&:to_i).include?(id)
  end

  def usable_for_merchants?(scenario)
    !(occupied? || rebelling?(scenario))
  end
end
