# frozen_string_literal: true

class Shared::PlantType < ApplicationRecord
  self.table_name = "plant_types"

  FORGE = 13
  JEWELLER = 10

  belongs_to :plant_category, optional: true, class_name: "Shared::PlantCategory"
  belongs_to :fossil_type, optional: true, class_name: "Shared::FossilType"
  has_many :plant_levels, class_name: "Shared::PlantLevel"

  scope :extractive, -> { where(plant_category_id: Shared::PlantCategory.where(is_extractive: true)) }
  scope :processing, -> { where(plant_category_id: Shared::PlantCategory.where(is_extractive: false)) }

  def extractive?
    plant_category&.is_extractive || false
  end

  # Технологический gate (FR-20): кузница и ювелирка требуют «Ремесловых людей»
  def tech_gate
    [FORGE, JEWELLER].include?(id) ? "craftsmen" : nil
  end

  def gate_satisfied?
    gate = tech_gate
    return true if gate.nil?
    gate == "craftsmen" ? Shared::Technology.open?(Shared::Technology::CRAFTSMEN) : false
  end
end
