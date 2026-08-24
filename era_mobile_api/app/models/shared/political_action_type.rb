# frozen_string_literal: true

class Shared::PoliticalActionType < ApplicationRecord
  self.table_name = "political_action_types"

  belongs_to :job, optional: true, class_name: "Shared::Job"
end
