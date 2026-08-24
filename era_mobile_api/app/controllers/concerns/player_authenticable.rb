# frozen_string_literal: true

# Bearer-аутентификация игрока (ТЗ 5.1, 11).
module PlayerAuthenticable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_player!
  end

  private

  attr_reader :current_session, :current_player

  def authenticate_player!
    raw = request.headers["Authorization"].to_s.delete_prefix("Bearer ").strip
    session_and_player = Mb::Session.authenticate(raw)
    return render json: { error: "Требуется вход по QR-коду" }, status: :unauthorized if session_and_player.nil?

    @current_session, @current_player = session_and_player
  end

  # Хранилище игрока с учётом правила «собственность членов гильдии — гильдии» (6.3)
  def scenario
    @scenario ||= Mb::ScenarioConfig.current
  end

  def my_storage
    current_player.effective_storage(scenario)
  end
end
