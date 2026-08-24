# frozen_string_literal: true

class Mb::Session < ApplicationRecord
  self.table_name = "mb_sessions"

  belongs_to :player, class_name: "Shared::Player"

  enum status: { active: 0, closed: 1, revoked: 2 }

  scope :active, -> { where(status: :active) }

  TTL_HOURS = (Rails.application.config.x.game[:session_ttl_hours] if defined?(Rails)).to_i

  # FR-4: один игрок = одно активное устройство; новый вход ревокует прежнюю сессию.
  def self.open_for!(player, device_info: nil)
    transaction do
      old = Mb::Session.where(player_id: player.id, status: :active).lock.first
      old&.update!(status: :revoked, closed_at: Time.current)
      create!(
        player_id: player.id,
        token_hash: Digest::SHA256.hexdigest(SecureRandom.hex(32)),
        device_info: device_info,
        last_seen_at: Time.current
      )
    end
  end

  def self.authenticate(raw_token)
    return nil if raw_token.blank?

    digest = digest_for(raw_token)
    s = active.find_by(token_hash: digest)
    return nil unless s

    s.update_column(:last_seen_at, Time.current)
    [s, Shared::Player.find(s.player_id)]
  end

  def self.digest_for(raw_token)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, raw_token.to_s)
  end

  def close!
    update!(status: :closed, closed_at: Time.current)
  end
end
