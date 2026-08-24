# frozen_string_literal: true

module Api::V1
  # Центр уведомлений (FR-39).
  class NotificationsController < BaseController
    def index
      notes = Mb::Notification.where(player_id: current_player.id).recent_first.limit(100)
      render json: {
        notifications: notes.map do |n|
          { id: n.id, kind: n.kind, title: n.title, body: n.body, payload: n.payload,
            read: n.read, created_at: n.created_at }
        end,
        unread_count: notes.unread.count
      }
    end

    # POST /api/v1/notifications/read { ids: [...] } или все
    def mark_read
      scope = Mb::Notification.where(player_id: current_player.id, read: false)
      scope = scope.where(id: Array(params[:ids]).map(&:to_i)) if params[:ids].present?
      scope.update_all(read: true)
      render json: { ok: true }
    end
  end
end
