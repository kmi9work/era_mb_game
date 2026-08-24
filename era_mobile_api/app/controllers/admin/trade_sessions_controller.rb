# frozen_string_literal: true

module Admin
  # FR-51: мониторинг торговли в реальном времени.
  class TradeSessionsController < BaseController
    # GET /admin_api/trade_sessions
    def index
      live = Mb::TradeSession.where(status: [Mb::TradeSession.statuses[:pending], Mb::TradeSession.statuses[:active]])
      render json: {
        active_sessions: live.map do |s|
          {
            id: s.id,
            status: s.status,
            initiator: { id: s.initiator_id, name: s.initiator&.display_name },
            partner: { id: s.partner_id, name: s.partner&.display_name },
            offers_a: s.offers_a,
            offers_b: s.offers_b,
            confirmed_a: s.confirmed_a,
            confirmed_b: s.confirmed_b,
            updated_at: s.updated_at
          }
        end
      }
    end
  end
end
