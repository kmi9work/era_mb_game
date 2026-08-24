# frozen_string_literal: true

module Api::V1
  # История операций хранилища с фильтрами по типу и году (FR-37).
  class OperationsController < BaseController
    MAX_LIMIT = 100

    def index
      storage = my_storage
      scope = Mb::Operation.for_subject(storage.type, storage.id)
      scope = scope.of_kind(params[:kind]) if params[:kind].present?
      scope = scope.in_year(params[:year].to_i) if params[:year].present?
      limit = [params.fetch(:limit, 50).to_i, MAX_LIMIT].min
      ops = scope.limit(limit)

      render json: {
        operations: OperationSerializer.serialize_list(ops),
        total: scope.count
      }
    end
  end
end
