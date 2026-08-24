# frozen_string_literal: true

class Shared::TechnologyItem < ApplicationRecord
  self.table_name = "technology_items"

  belongs_to :technology, optional: true, class_name: "Shared::Technology"
end
