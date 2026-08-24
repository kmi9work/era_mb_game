# frozen_string_literal: true

class Shared::PlantPlace < ApplicationRecord
  self.table_name = "plant_places"

  belongs_to :plant_category, optional: true, class_name: "Shared::PlantCategory"
  belongs_to :region, optional: true, class_name: "Shared::Region"
  has_and_belongs_to_many :fossil_types, join_table: "fossil_types_plant_places",
                                         class_name: "Shared::FossilType"
end
