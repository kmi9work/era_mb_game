# frozen_string_literal: true

class Shared::Job < ApplicationRecord
  self.table_name = "jobs"

  has_and_belongs_to_many :players, join_table: "jobs_players", class_name: "Shared::Player"
end
