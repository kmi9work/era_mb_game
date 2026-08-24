# frozen_string_literal: true

# Пуши FCM/APNs (FR-18, FR-38). FCM — напрямую; APNs — через релей (README).
class PushJob < ApplicationJob
  queue_as :pushes

  def perform(player_id, title, body, payload = {})
    player = Shared::Player.find_by(id: player_id)
    return if player.nil?

    tokens = Mb::PushToken.where(player_id: player.id).pluck(:platform, :token)
    return if tokens.empty?

    fcm_tokens = tokens.select { |p, _| p == "fcm" }.map { |_, t| t }
    PushService::Fcm.deliver(fcm_tokens, title: title, body: body, payload: payload) if fcm_tokens.any?
  rescue StandardError => e
    Rails.logger.warn("[Push] failed: #{e.class}: #{e.message}")
  end
end
