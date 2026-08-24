# frozen_string_literal: true

# FR-2..FR-5: вход сканом своего QR.
class AuthController < ApplicationController
  # POST /auth/login  { qr_string, device_info }
  def login
    device = params[:device_info]
    device = device.to_unsafe_h.to_json if device.respond_to?(:to_unsafe_h)
    device = device.to_s

    result = AuthService.login(
      qr_string: params[:qr_string].to_s,
      device_info: device
    )

    if result.ok
      render json: {
        token: result.token,
        player: player_payload(result.player)
      }
    else
      render json: { error: result.error }, status: :unauthorized
    end
  end

  private

  def player_payload(p)
    {
      id: p.id,
      name: p.display_name,
      identificator: p.identificator,
      guild_id: p.guild_id
    }
  end
end
