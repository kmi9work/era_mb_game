# frozen_string_literal: true

# Тестовая база изолирована от общей (era_mobile_api_test).
# Перед тестами разворачиваем: mb_* миграции + песочницу общих таблиц + демо-справочники.
RSpec.configure do |config|
  config.before(:suite) do
    # Песочница общих таблиц eraofchange (idempotent: if_not_exists)
    system("RAILS_ENV=test bin/rails db:migrate era_sandbox:install", err: File::NULL, out: File::NULL)
    # Демо-справочники — всегда (идемпотентны: find_or_create_by)
    load Rails.root.join("db/demo_seeds.rb")
  end
end
