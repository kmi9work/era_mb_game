# frozen_string_literal: true

# Печать QR на бейджи (FR-1): переиспользует поток eraofchange /qr_codes.
# GET /qr_codes — список игроков с их QR-строками (для печатной страницы era_front)
# GET /qr_codes/:player_id.png — PNG персонального QR
class QrCodesController < ApplicationController
  MASTER_KEY = ENV.fetch("MB_MASTER_KEY", "dev-master-key")

  before_action :authenticate_master!

  def index
    players = Shared::Player.order(:id).includes(mb_id_tokens: nil).map do |p|
      token = p.mb_id_tokens.where(status: :active).first
      {
        player_id: p.id,
        name: p.display_name,
        guild_id: p.guild_id,
        qr_issued: token.present?,
        qr_string: token&.qr_string
      }
    end
    render json: { players: players }
  end

  def show
    player = Shared::Player.find(params[:player_id])
    token = player.mb_id_tokens.active_tokens.first
    return render json: { error: "QR не выпущен" }, status: :not_found unless token

    png = RQRCode::QRCode.new(token.qr_string, level: :m).as_png(size: 480)
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
