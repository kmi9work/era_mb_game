# frozen_string_literal: true

module Api::V1
  # Лобби — главный экран (FR-6..FR-9).
  class LobbyController < BaseController
    # GET /api/v1/lobby
    def show
      cycle = Shared::GameParameter.cycle_state
      balance = StorageSerializer.balance_full(player: current_player, scenario: scenario)

      render json: {
        year: cycle[:year],
        years_total: Shared::GameParameter.years_count,
        cycle_item: cycle[:cycle_item],
        seconds_left: cycle[:seconds_left],
        player: { id: current_player.id, name: current_player.display_name },
        storage: balance,
        trade_session_busy: Mb::TradeSession.live_of(current_player).exists?
      }
    end
  end
end
