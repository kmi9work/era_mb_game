# frozen_string_literal: true

module Api::V1
  # Регистрация push-токена устройства.
  class PushTokensController < BaseController
    def create
      token = Mb::PushToken.find_or_initialize_by(
        platform: params[:platform].to_s,
        token: params[:token].to_s
      )
      token.player_id = current_player.id
      token.last_seen_at = Time.current
      token.save!
      render json: { ok: true }
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end
end
