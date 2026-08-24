# frozen_string_literal: true

module Api::V1
  # Предприятия (FR-19..FR-24). Метрика кликов: покупка ≤5 тапов, производство ≤2.
  class PlantsController < BaseController
    # GET /api/v1/plants — список моих предприятий + каталог + доступные земли
    def index
      render json: {
        plants: PlantService.list(my_storage),
        catalog: PlantService.catalog,
        scenario_flags: { guild_owns_member_property: scenario.flag?("guild_owns_member_property") }
      }
    end

    # GET /api/v1/plants/available_places?plant_type_id=N — земли под выбранный тип
    def available_places
      render json: {
        places: PlantService.available_places(params[:plant_type_id].to_i, scenario)
      }
    end

    # POST /api/v1/plants/purchase { plant_type_id, plant_place_id, to_level }
    def purchase
      plant = nil
      with_idempotency do |key|
        plant = PlantService.purchase!(
          player: current_player, scenario: scenario,
          plant_type_id: params[:plant_type_id].to_i,
          plant_place_id: params[:plant_place_id].to_i,
          to_level: params[:to_level].to_i,
          idempotency_key: key.presence || request.headers["X-Idempotency-Key"].presence || "purchase:#{current_player.id}:#{params[:plant_type_id]}:#{Time.current.to_i}"
        )
        CableBroadcast.balance_changed(my_storage)
      end
      render json: { plant: plant.is_a?(Shared::Plant) ? PlantService.plant_json(plant) : plant }
    rescue PlantService::RuleError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue StorageService::InsufficientFunds => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # PATCH /api/v1/plants/:id/upgrade { to_level }
    def upgrade
      with_idempotency do |key|
        plant = my_plant(params[:id])
        updated = PlantService.upgrade!(
          player: current_player, scenario: scenario, plant: plant,
          to_level: params[:to_level].to_i,
          idempotency_key: key.presence || "upgrade:#{plant.id}:#{params[:to_level]}"
        )
        CableBroadcast.balance_changed(my_storage)
        render json: { plant: PlantService.plant_json(updated) }
      end
    rescue PlantService::RuleError, StorageService::InsufficientFunds => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # POST /api/v1/plants/:id/sell — за залоговую стоимость текущего уровня (FR-22)
    def sell
      op = nil
      with_idempotency do |key|
        plant = my_plant(params[:id])
        op = PlantService.sell!(player: current_player, scenario: scenario, plant: plant,
                                idempotency_key: key.presence || "sell:#{plant.id}")
        CableBroadcast.balance_changed(my_storage)
      end
      render json: { sold: true, operation: OperationSerializer.serialize(op) }
    rescue PlantService::RuleError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # POST /api/v1/plants/:id/produce — кнопка «Произвести» (≤2 тапа)
    def produce
      with_idempotency do |key|
        plant = my_plant(params[:id])
        op = PlantService.produce!(player: current_player, scenario: scenario, plant: plant)
        _ = key
        CableBroadcast.balance_changed(my_storage)
        render json: { operation: OperationSerializer.serialize(op) }
      end
    rescue PlantService::RuleError, StorageService::InsufficientFunds => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # POST /api/v1/plants/produce_all — «Произвести на всех доступных» (1 тап + подтверждение)
    def produce_all
      result = PlantService.produce_all!(player: current_player, scenario: scenario)
      CableBroadcast.balance_changed(my_storage)
      render json: result
    end

    private

    def my_plant(id)
      Shared::Plant.of_owner(my_storage.type, my_storage.id).find(id)
    end
  end
end
