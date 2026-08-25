# frozen_string_literal: true

module Admin
  # FR-50: игроки, QR, сессии.
  class PlayersController < BaseController
    # GET /admin_api/players
    def index
      players = Shared::Player.order(:id).map do |p|
        {
          id: p.id,
          name: p.display_name,
          identificator: p.identificator,
          guild_id: p.guild_id,
          active_session: p.mb_sessions.active.select(:id, :device_info, :last_seen_at).last&.as_json,
          # QR существует всегда: era_front /players генерирует его из identificator.
          qr_issued: p.identificator.present?
        }
      end

      render json: { players: players }
    end

    # GET /admin_api/players/:player_id/sessions — активные устройства/сессии
    def sessions
      player = Shared::Player.find(params[:player_id])
      render json: {
        sessions: player.mb_sessions.order(created_at: :desc).limit(20).map do |s|
          { id: s.id, status: s.status, device_info: s.device_info,
            last_seen_at: s.last_seen_at, created_at: s.created_at }
        end
      }
    end

    # DELETE /admin_api/sessions/:id — принудительный логаут
    def destroy_session
      session = Mb::Session.find(params[:id])
      session.update!(status: :revoked, closed_at: Time.current)
      CableBroadcast.session_revoked(session)
      Mb::Notification.notify!(player_id: session.player_id, kind: "session_revoked",
                               title: "Сессия завершена", body: "Мастер завершил вашу сессию", push: true)
      render json: { ok: true }
    end
  end
end
