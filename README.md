# era_mb_game — мобильная игра «Эра перемен» (экономика купцов)

Реализация [ТЗ](../tz-mobile-game.md): мобильное приложение игрока-Купца + отдельный
бэкенд `era_mobile_api`, подключённый к единой базе PostgreSQL eraofchange.

## Состав репозитория

```
era_mb_game/
├── era_mobile_api/   # Rails 7.0 API (Ruby 3.2.2) — правила игры, журнал, realtime
└── era_mobile_app/   # React Native приложение игрока (Android APK + iOS)
```

## Быстрый старт бэкенда

```bash
cd era_mobile_api
bundle install                                   # прокси сбросить: env -u HTTP_PROXY ...
cp config/database.yml ...                       # уже настроено на общую базу (см. ниже)
bin/rails db:create db:migrate                   # mb_* таблицы
bin/rails era_sandbox:install                    # песочница общих таблиц eraofchange (dev)
bin/rails runner "load(Rails.root.join('db/demo_seeds.rb'))"   # демо-гильдии/игроки/страны
bin/rails s -p 3000                              # API + ActionCable /cable
# Отдельно: Sidekiq для отложенных караванов и пушей
bundle exec sidekiq -C config/sidekiq.yml        # требует redis://localhost:6379/1
```

### База данных

`config/database.yml` в dev указывает на **общую базу eraofchange** (`ERA_MB_DATABASE`,
по умолчанию `era_buggy`). era_mobile_api владеет только таблицами `mb_*`; схему общих
таблиц меняет только eraofchange (ТЗ 5.1). Тесты изолированы (`era_mobile_api_test`).

### Переменные окружения

| Переменная | Назначение |
|---|---|
| `MB_MASTER_KEY` | ключ админ-API для era_front (`X-Master-Key`) |
| `TRADE_SESSION_TIMEOUT` | таймаут торговой сессии, сек (120) |
| `REDIS_URL` | Redis для Sidekiq/ActionCable в проде |
| `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT_JSON` | пуши FCM |
| `ERA_MB_DATABASE`, `ERA_MB_DB_USER`, `ERA_MB_DB_PASSWORD` | подключение к общей БД |

## Админ-API для era_front (FR-50..FR-56)

Заголовок `X-Master-Key: $MB_MASTER_KEY`.

- `GET /admin_api/players` — игроки, активные устройства
- `DELETE /admin_api/sessions/:id` — принудительный логаут
- `GET /admin_api/trade_sessions` — мониторинг торговли live
- `GET /admin_api/operations?player_id=&kind=&year=` — журнал с фильтрами
- `POST /admin_api/corrections` — коррекции мастеров (комментарий обязателен)
- `POST /admin_api/operations/:id/revert` — отмена операции компенсацией
- `GET/PATCH /admin_api/caravans`, `POST /admin_api/caravans/:id/process_now`
- `GET /admin_api/integrity_check` — сверка целостности

Печать QR на бейджи: `GET /qr_codes` (список), `GET /qr_codes/:player_id.png`.

### Формат QR (единый с era_front)

Источник кодов — страница era_front `/players`: QR генерируется в браузере из
`{"type":"player_auth","identificator":"<код>","player_name":...,"generated_at":...}`.
Вход (`POST /auth/login`) и торговля (`partner_identificator`) проверяют
identificator по общей таблице players; подписные HMAC-токены выпилены
(миграция 20260826090000). Смена identificator мастером в era_front мгновенно
делает старый бейдж недействительным.

## Мобильное приложение

```bash
cd era_mobile_app
npm install
npm run android     # или npm run ios
```

Экраны: вход по QR → лобби (казна гильдии, год/таймер live по WebSocket) → мой QR,
торговля сканом (двустороннее подтверждение), предприятия (производство ≤2 тапов,
batch «на всех»), караваны (цены от отношений, эмбарго/контрабанда), политдействия
(кубик d20), история операций с фильтрами.

`src/config.ts` — адрес бэка (dev: эмулятор 10.0.2.2:3000; prod: шлюз с Basic Auth).

## Тесты

```bash
cd era_mobile_api
RAILS_ENV=test bin/rails db:migrate era_sandbox:install
bundle exec rspec          # 59 примеров: транзакции, гонки, идемпотентность,
                           # торговля, караваны+грабёж (статистически), вход по QR
```

## Соответствие ТЗ (ключевые решения)

- **Владение таблицами**: только `mb_*`; общий доступ через read-only зеркала моделей `Shared::*`.
- **Хранилища**: полиморфный владелец Player/Guild; флаг сценария `guild_owns_member_property`.
- **Деньги**: единый числовой баланс в ресурсе `gold`.
- **Идемпотентность**: `X-Idempotency-Key` на всех мутациях, уникальный индекс в журнале.
- **Журнал append-only**: исправления только компенсациями мастера (`master_correction`/`master_revert`).
- **Грабёж**: ролл P = остаток_ограблений / остаток_караванов в момент регистрации заявки;
  исход скрыт от игрока до обработки; мастер видит предрасчёт и может переопределить.
- **Караваны**: обработка джобой в момент T (настройка `caravan_process_minutes`),
  фиксация цен при отправке или обработке (`caravan_price_fixing`).
- **Технологии**: «Сельские школы» → апгрейды; «Технические училища» ×1.5;
  «Ремесловые люди» → кузница/ювелирка; «Заморская торговля» → игнор эмбарго.

## CI-сборки APK/IPA (GitHub Actions)

| Workflow | Что делает | Когда |
|---|---|---|
| `.github/workflows/android.yml` | `assembleRelease` → артефакт APK; по тегу `v*` — ещё и GitHub Release | пуш в main (пути `era_mobile_app/**`), теги, ручной запуск |
| `.github/workflows/ios.yml` | pod install + xcodebuild archive → unsigned IPA в артефакты; по тегу `v*` — Release | те же события, runner macos-14 |
| `.github/workflows/backend.yml` | rspec на postgres 16 + redis | пуш/PR по `era_mobile_api/**` |

### Подпись Android (опционально)

Без секретов APK подписывается debug-ключом (коммитится в репо) — ставится на
устройство напрямую, что соответствует ТЗ разд. 4. Для release-подписи добавьте
Secrets репозитория:

- `ANDROID_KEYSTORE_BASE64` — base64 вашего keystore: `base64 -w0 my-release.keystore`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD` (если отличается от store password)

### Подпись iOS (опционально)

Без секретов собирается **unsigned IPA** (Payload/*.app в zip) — подходит для
дистрибуции через AltStore/Sideloadly или Xcode у себя. Для подписанной сборки:

- `CERTIFICATE_P12_BASE64` — сертификат распространения (Apple Distribution)
- `P12_PASSWORD`
- `BUILD_PROVISION_PROFILE_BASE64` — provisioning profile

Для App Store/TestFlight нужен аккаунт разработчика и отдельный шаг
`xcrun altool`/`notarytool` — добавляется после получения учётных данных.

### Статус (2026-08-24)

- **android-apk: зелёный** — APK собирается на каждый пуш в main (артефакт 25.7 MB,
  debug-подпись; ставится на устройство напрямую).
- **backend (rspec): зелёный**.
- **ios-ipa: требует отладки** — шаг `pod install` падает на macos-14 раннере;
  логи GitHub Actions закрыты для анонимного доступа, поэтому для диагностики нужен
  либо `gh run view --log` под вашим аккаунтом, либо токен с правом `actions:read`
  (положить в `~/.config/gh/hosts.yml` через `gh auth login`).
