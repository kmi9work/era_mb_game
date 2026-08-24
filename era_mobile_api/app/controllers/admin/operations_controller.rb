# frozen_string_literal: true

module Admin
  class OperationsController < BaseController
    # GET /admin_api/operations?player_id=&kind=&year=
    def index
      scope = Mb::Operation.order(created_at: :desc).limit(500)
      scope = scope.where(subject_type: "Player", subject_id: params[:player_id]) if params[:player_id]
      scope = scope.of_kind(params[:kind]) if params[:kind]
      scope = scope.in_year(params[:year]) if params[:year]

      render json: {
        operations: OperationSerializer.serialize_list(scope.includes(:operation_items, :initiator))
      }
    end

    # POST /admin_api/operations/:id/revert { comment } — FR-53
    def revert
      op = Mb::Operation.find(params[:id])
      comment = params.require(:comment)
      revert_op = op.revert!(master_comment: comment)
      render json: {
        reverted_operation: OperationSerializer.serialize(op),
        compensation: OperationSerializer.serialize(revert_op)
      }
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
