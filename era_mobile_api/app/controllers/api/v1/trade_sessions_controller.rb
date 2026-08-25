# frozen_string_literal: true

module Api::V1
  # Торговля по QR (FR-11..FR-18).
  class TradeSessionsController < BaseController
    # POST /api/v1/trade_sessions { partner_identificator } (QR из era_front)
    # или { partner_player_id } (legacy)
    def create
      partner = find_partner
      return render json: { error: "Игрок не найден" }, status: :not_found if partner.nil?
      return render json: { error: "Нельзя торговать с самим собой" }, status: :unprocessable_entity if partner.id == current_player.id
      return render json: { error: "Игрок офлайн или занят другой сделкой" }, status: :conflict unless partner_online?(partner)

      session = Mb::TradeSession.start!(initiator: current_player, partner: partner)
      CableBroadcast.trade_invite(session, current_player, partner)
      Mb::Notification.notify!(
        player: partner, kind: "trade_invite",
        title: "Предложение торговли",
        body: "#{current_player.display_name} предлагает торговлю",
        payload: { trade_session_id: session.id }, push: true
      )
      render json: trade_payload(session)
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.record.errors.full_messages.to_sentence }, status: :conflict
    end

    # GET /api/v1/trade_sessions/:id
    def show
      session = find_session
      return render json: { error: "Сессия не найдена" }, status: :not_found if session.nil?

      render json: trade_payload(session)
    end

    # POST /api/v1/trade_sessions/:id/offer { money, resources: [...], cards: [...] }
    def update_offer
      session = find_session(live: true)
      return render json: { error: "Активная сессия не найдена" }, status: :not_found if session.nil?

      items = {
        money: params[:money],
        resources: (params[:resources] || []).map(&:to_unsafe_h),
        cards: params[:cards]
      }
      ok = session.set_offer!(current_player, items)
      CableBroadcast.trade_state(session)

      if ok
        render json: trade_payload(session)
      else
        render json: { error: "Сделка уже завершена" }, status: :conflict
      end
    end

    # POST /api/v1/trade_sessions/:id/confirm
    def confirm
      session = find_session(live: true)
      return render json: { error: "Активная сессия не найдена" }, status: :not_found if session.nil?

      # Ограничение сверху при вводе количества (FR-13) — финальная проверка на сервере
      error = validate_against_storage(session)
      return render json: { error: error }, status: :unprocessable_entity if error

      ok, message, operation = session.confirm!(current_player)
      CableBroadcast.trade_state(session)

      if ok && operation
        render json: { status: "completed", operations: OperationSerializer.serialize_list([operation]) }
      elsif ok
        render json: trade_payload(session)
      else
        render json: { error: message }, status: :conflict
      end
    end

    # DELETE /api/v1/trade_sessions/:id — отменить ДО исполнения (FR-16: после исполнения отмена только мастером)
    def cancel
      session = find_session(live: true)
      return render json: { error: "Активная сессия не найдена" }, status: :not_found if session.nil?

      session.cancel!
      CableBroadcast.trade_state(session)
      render json: { status: "cancelled" }
    end

    private

    def find_session(live: false)
      scope = Mb::TradeSession.where(id: params[:id])
                              .where("initiator_id = ? OR partner_id = ?", current_player.id, current_player.id)
      scope = scope.where(status: [Mb::TradeSession.statuses[:pending], Mb::TradeSession.statuses[:active]]) if live
      scope.first
    end

    def find_partner
      ident = params[:partner_identificator].to_s.strip
      return Shared::Player.find_by(identificator: ident) if ident.present?

      Shared::Player.find_by(id: params[:partner_player_id])
    end

    def partner_online?(partner)
      Mb::Session.active.exists?(player_id: partner.id)
    end

    def validate_against_storage(session)
      offer = session.offer_for(current_player)
      storage = my_storage
      balance = StorageService.balance(storage)

      return "Недостаточно золота" if offer["money"].to_i > balance[:money]

      res_map = balance[:resources].each_with_object({}) { |r, h| h[r[:identificator]] = r[:count] }
      Array(offer["resources"]).each do |r|
        have = res_map[r["identificator"]].to_i
        if r["count"].to_i > have
          return "Недостаточно ресурсов #{StorageService.resource_name(r['identificator'])} (есть: #{have})"
        end
      end

      card_ids = balance[:cards].map { |c| c[:id] }
      Array(offer["cards"]).each do |cid|
        return "Карточки нет в хранилище" unless card_ids.include?(cid.to_i)
      end
      nil
    end

    def trade_payload(session)
      other = session.other(current_player)
      {
        id: session.id,
        status: session.status,
        partner: { id: other.id, name: other.display_name },
        your_offer: session.offer_for(current_player),
        you_confirmed: session.confirmed_for?(current_player),
        role: session.role_of(current_player).to_s
      }
    end
  end
end
