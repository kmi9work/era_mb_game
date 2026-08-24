# frozen_string_literal: true

module Api::V1
  # Политдействия купцов — доступно главе гильдии (FR-32..FR-34). ≤3 тапа.
  class PoliticalActionsController < BaseController
    before_action :require_guild_boss!

    # GET /api/v1/political_actions
    def index
      render json: { actions: PoliticalActionService.available(player: current_player) }
    end

    # POST /api/v1/political_actions/:id/perform
    def perform
      pat = Shared::PoliticalActionType.find(params[:id])
      result = PoliticalActionService.perform!(
        player: current_player, scenario: scenario,
        political_action_type: pat,
        idempotency_key: request.headers["X-Idempotency-Key"]
      )

      if result.ok
        CableBroadcast.balance_changed(my_storage)
        render json: {
          success: result.success,
          roll: result.roll&.slice(:roll, :threshold),
          card: result.card && { id: result.card.id, kind: result.card.card_kind, name: result.card.display_name }
        }
      else
        render json: { error: result.error }, status: :unprocessable_entity
      end
    rescue PoliticalActionService::RuleError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def require_guild_boss!
      return if current_player.guild_boss?
      render json: { error: "Доступно только главе гильдии" }, status: :forbidden
    end
  end
end
