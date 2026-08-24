# frozen_string_literal: true

# Админ-API для era_front. Транспорт: Basic Auth шлюза + X-Master-Key (мастер экономики).
class Admin::BaseController < ApplicationController
  MASTER_KEY = ENV.fetch("MB_MASTER_KEY", "dev-master-key")

  before_action :authenticate_master!

  private

  def authenticate_master!
    provided = request.headers["X-Master-Key"].to_s
    return render json: { error: "Доступ только для мастеров" }, status: :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(provided, MASTER_KEY)
  end
end
