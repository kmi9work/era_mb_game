# frozen_string_literal: true

# Персональный QR-идентификатор игрока (FR-1): UUID + HMAC-подпись.
# Payload QR: {"t":"mb_player_auth","pid":<player_id>,"u":<uuid>,"s":<hmac>}
class Mb::IdToken < ApplicationRecord
  self.table_name = "mb_id_tokens"

  belongs_to :player, class_name: "Shared::Player"

  enum status: { active: 0, revoked: 1 }

  HMAC_KEY = (ENV["MB_QR_SECRET"] if defined?(ENV)) || "dev-only-key"

  scope :active_tokens, -> { where(status: :active) }

  def self.issue_for!(player)
    transaction do
      Mb::IdToken.where(player_id: player.id, status: :active).update_all(
        status: Mb::IdToken.statuses[:revoked], revoked_at: Time.current
      )
      public_id = SecureRandom.uuid
      create!(
        player_id: player.id,
        public_id: public_id,
        secret_digest: signature(player.id, public_id),
        payload_digest: Digest::SHA256.hexdigest(payload_of(player.id))
      )
    end
  end

  def self.signature(player_id, public_id)
    OpenSSL::HMAC.hexdigest("SHA256", hmac_key, "mb|#{player_id}|#{public_id}")
  end

  def self.hmac_key
    defined?(Rails) ? (ENV["MB_QR_SECRET"] || Rails.application.secret_key_base) : "dev"
  end

  def self.payload_of(player_id)
    "#{player_id}:#{Digest::SHA256.hexdigest(hmac_key)[0, 16]}"
  end

  def qr_string
    { t: "mb_player_auth", pid: player_id, u: public_id, s: secret_digest }.to_json
  end

  def to_qr_png(size: 480)
    RQRCode::QRCode.new(qr_string, level: :m).as_png(size: size).to_s
  end
end
