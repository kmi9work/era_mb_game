# frozen_string_literal: true

class Mb::PushToken < ApplicationRecord
  self.table_name = "mb_push_tokens"

  belongs_to :player, class_name: "Shared::Player"

  validates :platform, inclusion: { in: %w[fcm apns] }
  validates :token, presence: true
end
