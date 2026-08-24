# frozen_string_literal: true

# Центр уведомлений (FR-38, FR-39): лента событий + пуш.
class Mb::Notification < ApplicationRecord
  self.table_name = "mb_notifications"

  belongs_to :player, class_name: "Shared::Player"

  scope :unread, -> { where(read: false) }
  scope :recent_first, -> { order(created_at: :desc) }

  def self.notify!(player:, kind:, title:, body: nil, payload: {}, push: true)
    n = create!(player_id: player.id, kind: kind, title: title, body: body, payload: payload)
    ::PushJob.perform_later(player.id, title, body, payload.symbolize_keys) if push
    CableBroadcast.lobby(player)
    n
  end
end
