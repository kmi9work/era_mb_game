# frozen_string_literal: true

module Api::V1
  # Караваны (FR-25..FR-31).
  class CaravansController < BaseController
    # GET /api/v1/caravans
    def index
      render json: CaravanService.list(player: current_player, scenario: scenario)
    end

    # POST /api/v1/caravans { country_id, sell_items, buy_items, use_contraband }
    def create
      result = CaravanService.send!(
        player: current_player, scenario: scenario,
        country_id: params[:country_id].to_i,
        sell_items: (params[:sell_items] || []).map(&:to_unsafe_h),
        buy_items: (params[:buy_items] || []).map(&:to_unsafe_h),
        use_contraband: ActiveModel::Type::Boolean.new.cast(params[:use_contraband]),
        idempotency_key: request.headers["X-Idempotency-Key"]
      )

      if result.ok
        render json: { caravan: CaravanService.caravan_json(result.caravan, public: true) }
      else
        render json: { error: result.error }, status: :unprocessable_entity
      end
    end

    # GET /api/v1/countries — страны с отношениями и ценами (FR-25)
    def countries_view; end
  end
end
