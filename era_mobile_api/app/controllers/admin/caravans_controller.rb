# frozen_string_literal: true

module Admin
  # FR-54: список заявок, предрасчёт исхода сразу после отправки,
  # изменение исхода/состава до обработки; ручная досрочная обработка.
  class CaravansController < BaseController
    # GET /admin_api/caravans?status=&year=
    def index
      scope = Mb::CaravanMobile.order(sent_at: :desc)
      scope = scope.where(status: params[:status]) if params[:status]
      scope = scope.where(year: params[:year]) if params[:year]
      render json: {
        caravans: scope.limit(200).map { |c| CaravanService.caravan_json(c, public: false) }
      }
    end

    # PATCH /admin_api/caravans/:id — изменение исхода и состава до момента обработки
    def update
      caravan = Mb::CaravanMobile.find(params[:id])
      return render json: { error: "Караван уже обработан" }, status: :unprocessable_entity unless caravan.in_transit?

      attrs = {}
      attrs[:precalculated_robbed] = ActiveModel::Type::Boolean.new.cast(params[:precalculated_robbed]) if params.key?(:precalculated_robbed)
      attrs[:sell_items] = CaravanService.normalize(params[:sell_items]) if params.key?(:sell_items)
      attrs[:buy_items] = CaravanService.normalize(params[:buy_items]) if params.key?(:buy_items)
      attrs[:process_at] = Time.zone.parse(params[:process_at].to_s) if params.key?(:process_at)

      caravan.update!(attrs.compact)
      render json: { caravan: CaravanService.caravan_json(caravan, public: false) }
    end

    # POST /admin_api/caravans/:id/process_now — ручная досрочная обработка
    def process_now
      caravan = Mb::CaravanMobile.find(params[:id])
      return render json: { error: "Караван уже обработан" }, status: :unprocessable_entity unless caravan.in_transit?

      force = case params[:result]&.to_s
              when "robbed" then :robbed
              when "ok" then :ok
              else nil
              end
      processed = CaravanService.process!(caravan, force_result: force)
      render json: { caravan: CaravanService.caravan_json(processed, public: false) }
    end
  end
end
