# frozen_string_literal: true

# Печать QR на бейджи (FR-1): тот же формат, что генерирует era_front /players.
# GET /qr_codes — список игроков с QR-строками (мастера, X-Master-Key)
# GET /qr_codes/:player_id.png — PNG персонального QR
class QrCodesController < ApplicationController
  MASTER_KEY = ENV.fetch("MB_MASTER_KEY", "dev-master-key")

  before_action :authenticate_master!

  def index
    players = Shared::Player.order(:id).map do |p|
      {
        player_id: p.id,
        name: p.display_name,
        guild_id: p.guild_id,
        qr_issued: p.identificator.present?,
        qr_string: p.identificator.present? ? QrStringBuilder.build(p) : nil
      }
    end
    render json: { players: players }
  end

  def show
    player = Shared::Player.find(params[:player_id])
    return render json: { error: "У игрока нет идентификатора" }, status: :not_found if player.identificator.blank?

    png = RQRCode::QRCode.new(QrStringBuilder.build(player), level: :m).as_png(size: 480)
    send_data png.to_s, type: "image/png", disposition: "inline",
                        filename: "qr_player_#{player.id}.png"
  end

  private

  def authenticate_master!
    provided = request.headers["X-Master-Key"].to_s
    return if ActiveSupport::SecurityUtils.secure_compare(provided, MASTER_KEY)

    render json: { error: "Доступ только для мастеров" }, status: :unauthorized
  end
end
