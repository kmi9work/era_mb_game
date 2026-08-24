# frozen_string_literal: true

class Mb::OperationItem < ApplicationRecord
  self.table_name = "mb_operation_items"

  belongs_to :operation, class_name: "Mb::Operation"

  validates :identificator, presence: true
  validates :delta, numericality: { only_integer: true }
end
