require_relative "boot"

require "rails"
# API-only приложение (ТЗ 5.1)
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module EraMobileApi
  class Application < Rails::Application
    config.load_defaults 7.0

    config.api_only = true

    # Русские сообщения моделей пишутся прямо в коде (валидации), i18n оставляем en,
    # чтобы I18n.translate для ошибок ассоциаций не падал без словаря.
    config.i18n.available_locales = %i[en ru]
    config.i18n.default_locale = :en

    config.time_zone = "Moscow"

    # ActionCable: допускать RN-клиенты (dev-метро, эмуляторы) — origin проверяется только в prod
    config.action_cable.allowed_request_origins = [%r{https?://.*}, %r{ws://.*}, %r{wss://.*}] if Rails.env.development?
    config.action_cable.disable_request_forgery_protection = true if Rails.env.development?

    # Сервисы/модели домена
    config.eager_load_paths << Rails.root.join("app/services")
    config.eager_load_paths << Rails.root.join("lib/game")

    # Игровые правила — серверные константы (ТЗ 1.4 п.3)
    config.x.game = {
      trade_session_timeout_seconds: Integer(ENV.fetch("TRADE_SESSION_TIMEOUT", 120)),
      caravan_processing_poll_seconds: 2,
      idempotency_ttl_hours: 24,
      session_ttl_hours: 12
    }.freeze
  end
end
