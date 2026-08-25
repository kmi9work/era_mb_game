# Era Mobile API routes (deploy trigger 2)
Rails.application.routes.draw do
  mount ActionCable.server => "/cable"

  # ─── Игрок (мобильное приложение, Bearer-токен) ────────────────────────────
  post   "/auth/login",            to: "auth#login"

  scope "/api/v1", module: "api/v1", defaults: { format: :json } do
    get    "/lobby",               to: "lobby#show"
    post   "/trade_sessions",      to: "trade_sessions#create"
    get    "/trade_sessions/:id",  to: "trade_sessions#show"
    post   "/trade_sessions/:id/offer", to: "trade_sessions#update_offer"
    post   "/trade_sessions/:id/confirm", to: "trade_sessions#confirm"
    post   "/trade_sessions/:id/cancel",  to: "trade_sessions#cancel"
    delete "/trade_sessions/:id",  to: "trade_sessions#cancel"

    resources :plants, only: [:index] do
      collection do
        post :produce_all
      end
      member do
        post :buy
        patch :upgrade
        post :sell
        post :produce
      end
    end
    # Покупка: тип → земля → уровень → подтвердить (FR-20)
    post "/plants/purchase", to: "plants#purchase"

    get    "/caravans",            to: "caravans#index"
    post   "/caravans",            to: "caravans#create"
    get    "/countries",           to: "countries#index"
    get    "/political_actions",   to: "political_actions#index"
    post   "/political_actions/:id/perform", to: "political_actions#perform"

    get    "/guild",               to: "guilds#show"
    get    "/operations",          to: "operations#index"
    get    "/notifications",       to: "notifications#index"
    post   "/notifications/read",  to: "notifications#mark_read"
    post   "/push_tokens",         to: "push_tokens#create"
  end

  # ─── Админ-API для era_front (мастера; Basic Auth шлюза + X-Master-Key) ───
  scope "/admin_api", as: :admin_api, defaults: { format: :json } do
    constraints(master_key: /[^\/]+/) do
      # FR-50
      get    "/players",                    to: "admin/players#index"
      post   "/players/:player_id/regen_qr", to: "admin/players#regenerate_qr"
      get    "/players/:player_id/sessions", to: "admin/players#sessions"
      delete "/sessions/:id",               to: "admin/players#destroy_session"
      # FR-51
      get    "/trade_sessions",             to: "admin/trade_sessions#index"
      get    "/operations",                 to: "admin/operations#index"
      # FR-52
      post   "/corrections",                to: "admin/corrections#create"
      # FR-53
      post   "/operations/:id/revert",      to: "admin/operations#revert"
      # FR-54
      get    "/caravans",                   to: "admin/caravans#index"
      patch  "/caravans/:id",               to: "admin/caravans#update"
      post   "/caravans/:id/process_now",   to: "admin/caravans#process_now"
      # FR-56
      get    "/integrity_check",            to: "admin/integrity_checks#show"
    end
  end

  # Печать QR на бейджи (переиспользование потока eraofchange /qr_codes)
  get "/qr_codes",              to: "qr_codes#index"
  get "/qr_codes/:player_id.png", to: "qr_codes#show", as: :qr_code_png
end
