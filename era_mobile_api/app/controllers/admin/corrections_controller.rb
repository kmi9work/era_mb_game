# frozen_string_literal: true

module Admin
  # FR-52: цифровой аналог «мастер выдал жетон рукой».
  # Начислить/снять любые ресурсы, деньги, карточки любому хранилищу с обязательным комментарием.
  class CorrectionsController < BaseController
    # POST /admin_api/corrections
    # { subject_type: "Player"|"Guild", subject_id:, comment:,
    #   entries: [{identificator, delta, name?, is_card?, card_kind?}] }
    def create
      comment = params.require(:comment)
      raise ArgumentError, "Комментарий обязателен" if comment.strip.empty?

      storage = StorageService::ResourceRef.new(
        type: params.require(:subject_type).classify,
        id: params.require(:subject_id).to_i
      )
      StorageService.owner_for(storage) # валидация существования хранилища

      entries = (params.require(:entries) || []).map(&:to_unsafe_h).map do |e|
        {
          identificator: e["identificator"].to_s,
          name: e["name"].to_s,
          delta: e["delta"].to_i,
          is_card: ActiveModel::Type::Boolean.new.cast(e["is_card"]),
          card_kind: e["card_kind"].to_s.presence
        }
      end

      op = StorageService.adjust!(
        storage: storage, entries: entries, kind: "master_correction",
        idempotency_key: request.headers["X-Idempotency-Key"],
        comment: comment,
        meta: { master: true }
      )

      notify_subject(storage, comment)
      render json: { operation: OperationSerializer.serialize(op) }
    rescue ArgumentError, ActionController::ParameterMissing => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue ActiveRecord::RecordNotFound => e
      render json: { error: "Хранилище не найдено: #{e.message}" }, status: :not_found
    end

    private

    def notify_subject(storage, comment)
      players = if storage.type == "Guild"
                  Shared::Player.where(guild_id: storage.id)
                else
                  Shared::Player.where(id: storage.id)
                end
      players.find_each do |p|
        Mb::Notification.notify!(player: p, kind: "master_correction",
                                 title: "Коррекция мастера", body: comment, push: true)
      end
    end
  end
end
