# frozen_string_literal: true

module Api::V1
  # Экран гильдии (FR-35): название, состав, казна, флаг защиты, последние операции.
  class GuildsController < BaseController
    def show
      view = StorageSerializer.guild_view(player: current_player, scenario: scenario)
      return render json: { error: "Вы не состоите в гильдии" }, status: :not_found if view.nil?

      render json: { guild: view }
    end
  end
end
