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
| `MB_QR_SECRET` | HMAC-ключ QR-идентификаторов (по умолчанию secret_key_base) |
| `TRADE_SESSION_TIMEOUT` | таймаут торговой сессии, сек (120) |
| `REDIS_URL` | Redis для Sidekiq/ActionCable в проде |
| `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT_JSON` | пуши FCM |
| `ERA_MB_DATABASE`, `ERA_MB_DB_USER`, `ERA_MB_DB_PASSWORD` | подключение к общей БД |

## Админ-API для era_front (FR-50..FR-56)

Заголовок `X-Master-Key: $MB_MASTER_KEY`.

- `GET /admin_api/players` — игроки, активные устройства
- `POST /admin_api/players/:id/regen_qr` — перегенерация QR
- `DELETE /admin_api/sessions/:id` — принудительный логаут
- `GET /admin_api/trade_sessions` — мониторинг торговли live
- `GET /admin_api/operations?player_id=&kind=&year=` — журнал с фильтрами
- `POST /admin_api/corrections` — коррекции мастеров (комментарий обязателен)
- `POST /admin_api/operations/:id/revert` — отмена операции компенсацией
- `GET/PATCH /admin_api/caravans`, `POST /admin_api/caravans/:id/process_now`
- `GET /admin_api/integrity_check` — сверка целостности

Печать QR на бейджи: `GET /qr_codes` (список), `GET /qr_codes/:player_id.png`.

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
