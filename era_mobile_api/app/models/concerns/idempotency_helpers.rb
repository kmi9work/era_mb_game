# frozen_string_literal: true

# Хелперы идемпотентности контроллеров: повтор с тем же ключом возвращает прежний результат.
module IdempotencyHelpers
  extend ActiveSupport::Concern

  included do
    def with_idempotency(prefix = nil)
      key = request.headers["X-Idempotency-Key"].presence
      existing = StorageService.find_applied(key) if key.present? && prefix.blank?
      return render_operation_result(existing) if existing

      yield key
    end

    def render_operation_result(op)
      render json: {
        idempotent_replay: true,
        operation: OperationSerializer.serialize(op)
      }, status: :ok
    end
  end
end
