# frozen_string_literal: true

module ApplicationCable
  # Подключение по Bearer-токену сессии (тот же, что в REST API).
  class Connection < ActionCable::Connection::Base
    identified_by :current_player_id

    def connect
      self.current_player_id = find_verified_player_id
    end

    private

    def find_verified_player_id
      raw = request.params[:token].to_s
      session_and_player = Mb::Session.authenticate(raw)
      return reject_unauthorized_connection if session_and_player.nil?

      session_and_player[1].id
    end
  end
end
