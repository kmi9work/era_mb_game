# frozen_string_literal: true

class Shared::FossilType < ApplicationRecord
  self.table_name = "fossil_types"

  has_many :plant_types, class_name: "Shared::PlantType"
end
