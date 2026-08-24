# frozen_string_literal: true

# RN-приложение — нативный клиент, CORS нужен для dev-инструментов и web-прототипа.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "*"
    resource "/**",
             headers: :any,
             methods: %i[get post put patch delete options head],
             expose: %w[Authorization],
             credentials: false
  end
end
