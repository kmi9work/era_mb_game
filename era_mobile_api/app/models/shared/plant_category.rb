# frozen_string_literal: true

class Shared::PlantCategory < ApplicationRecord
  self.table_name = "plant_categories"

  has_many :plant_types, class_name: "Shared::PlantType"
end
