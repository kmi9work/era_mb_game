# ДЕПЛОЙ era_mb_game

## Архитектура

```
GitHub (main) ──push──▶ GitHub Actions
                          |  deploy.yml: release -> migrate -> seed -> switch -> restart -> health
                          v
        epoha-сервер deploy@62.173.148.168 (Debian 12)
          /opt/era/era_mb_game/
            |-- repo/         git-клон (git@github.com:kmi9work/era_mb_game.git)
            |-- releases/<ts> иммутабельные релизы
            |-- current --> releases/<ts>   симлинк активного релиза
            +-- shared/       log, pids, storage, bundle, era_mb_game.env
          systemd: era-mb-game.service (puma :3001), era-mb-game-sidekiq.service
          nginx: era-mb-game.igroteh.su -> 127.0.0.1:3001 (+ /cable WebSocket)
```

## Правила деплоя

1. **Единственный путь в production — push в main** (или ручной `workflow_dispatch`
   с выбором ветки). Прямые правки на сервере запрещены.
2. Деплой срабатывает только при изменениях в `era_mobile_api/**`, `deploy/**`
   или самом workflow — пуш только приложения (era_mobile_app) деплой API не дёргает.
3. **Иммутабельные релизы**: каждый деплой создаёт новую папку `releases/<timestamp-sha>`,
   `current` — симлинк. Откат = переключение симлинка на предыдущий релиз + рестарт
   (автоматический шаг Rollback on failure).
4. **Состояние — вне релиза**: логи, pids, storage, bundle-гемы и env-файл живут в
   `shared/` и линкуются внутрь релиза. Старый релиз можно удалять без потери данных.
5. **Миграции идемпотентны**: `db:migrate` и `db:seed` выполняются на каждом деплое;
   сиды написаны через find_or_create_by и безопасны при повторе.
6. **База**: отдельная `era_mb_game_production` (владелец deploy). Живая база настольной
   игры `eraofchange_production` деплоем мобильной игры не трогается.
7. **Секреты**: только через GitHub Secrets (DEPLOY_SSH_KEY) и серверный env-файл
   `/opt/era/era_mb_game/shared/era_mb_game.env`. В git не попадают.
8. **Рестарт сервисов** требует пароль sudo deploy — он передаётся в CI из секрета
   DEPLOY_PASSWORD (механизм описан в deploy.yml); вручную:
   `sudo systemctl restart era-mb-game era-mb-game-sidekiq`.
9. **Health check** после рестарта обязателен; провал -> автооткат на предыдущий релиз.

## Разовые настройки (уже выполнены)

- [x] Клон репо: `/opt/era/era_mb_game/repo`
- [x] База: `createdb era_mb_game_production`, пароль роли deploy выставлен
- [x] env-файл: `/opt/era/era_mb_game/shared/era_mb_game.env`
      (SECRET_KEY_BASE, MB_MASTER_KEY, MB_QR_SECRET — сгенерированы openssl;
      шаблон: deploy/era_mb_game.env.example)
- [x] systemd-юниты: deploy/systemd/*.service -> /etc/systemd/system/
- [x] nginx HTTP-конфиг + ACME; HTTPS — после выпуска сертификата certbot'ом

## Процедуры

### Первый выпуск сертификата (после обновления A-записи)

```bash
ssh -i ~/.ssh/id_ed25519 deploy@62.173.148.168
sudo certbot --nginx -d era-mb-game.igroteh.su
# затем раскатать https-конфиг с /cable-локацией (deploy/nginx/*https*)
sudo nginx -t && sudo systemctl reload nginx
```

### Ручной деплой (обход CI)

```bash
./deploy/deploy.sh main                 # подготовить release
./deploy/remote_activate.sh <stamp>     # bundle+migrate+seed+switch
sudo systemctl restart era-mb-game era-mb-game-sidekiq
```

### Откат вручную

```bash
ls -dt /opt/era/era_mb_game/releases/* | head -3     # найти предыдущий
ln -sfn /opt/era/era_mb_game/releases/<prev> /opt/era/era_mb_game/current
sudo systemctl restart era-mb-game era-mb-game-sidekiq
```

### Секреты GitHub (Settings -> Secrets and variables -> Actions)

| Secret           | Назначение                                              |
|------------------|---------------------------------------------------------|
| DEPLOY_SSH_KEY   | приватный ключ, которым Actions заходит на сервер       |
| DEPLOY_PASSWORD  | пароль deploy для рестарта сервисов через sudo в CI     |

Публичную часть DEPLOY_SSH_KEY нужно добавить в
`/home/deploy/.ssh/authorized_keys` на сервере.

### Порты соседей

epoha back0 занимает 127.0.0.1:3000 — мобильный API живёт на **3001**
(PUMA_PORT в env-файле).

### Известные ограничения

- sudo у deploy NOPASSWD только на `systemctl * passenger`; остальные команды sudo
  запрашивают пароль (в CI — из секрета DEPLOY_PASSWORD).
- DNS era-mb-game.igroteh.su изначально указывал на 62.173.138.248; исправлен на
  62.173.148.168 (TTL 1800 — до часа на распространение).
