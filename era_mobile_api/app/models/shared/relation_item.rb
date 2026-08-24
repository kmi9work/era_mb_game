# frozen_string_literal: true

class Shared::RelationItem < ApplicationRecord
  self.table_name = "relation_items"

  belongs_to :country, class_name: "Shared::Country"
end
