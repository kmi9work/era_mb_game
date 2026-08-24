#!/usr/bin/env bash
# Первичная настройка сервера epoha (deploy@62.173.148.168) под era_mb_game.
# Запускается ОДИН РАЗ вручную: ./deploy/server_bootstrap.sh
# sudo требуется только для systemctl/certbot — у deploy есть NOPASSWD на systemctl passenger,
# остальные systemctl-команды и certbot требуют пароль (вводится интерактивно).
set -euo pipefail

HOST=deploy@62.173.148.168
KEY=${KEY:-$HOME/.ssh/id_ed25519}
APP=/opt/era/era_mb_game

run() { ssh -t -i "$KEY" "$HOST" "$@"; }

echo "== 1. Каталоги приложения"
ssh -i "$KEY" "$HOST" "mkdir -p $APP/{releases,shared/{log,pids,storage,bundle,certs}}"

echo "== 2. env-файл (если ещё нет)"
ssh -i "$KEY" "$HOST" "
  if [ ! -f $APP/shared/era_mb_game.env ]; then
    SKB=\$(openssl rand -hex 64)
    MK=\$(openssl rand -hex 32)
    QS=\$(openssl rand -hex 32)
    sed -e \"s/CHANGE_ME_secret_key_base/\$SKB/\" \
        -e \"s/CHANGE_ME_master_key/\$MK/\" \
        -e \"s/CHANGE_ME_qr_secret/\$QS/\" \
        > $APP/shared/era_mb_game.env <<'ENVEOF'
RAILS_ENV=production
RAILS_LOG_TO_STDOUT=1
ERA_MB_DATABASE=era_mb_game_production
ERA_MB_DB_USER=deploy
ERA_MB_DB_PASSWORD=gfhjkm
SECRET_KEY_BASE=__SKB__
MB_MASTER_KEY=__MK__
MB_QR_SECRET=__QS__
TRADE_SESSION_TIMEOUT=120
REDIS_URL=redis://localhost:6379/2
PUMA_PORT=3001
ENVEOF
    echo \"env created\"
  else
    echo \"env already exists\"
  fi
"

echo "== 3. systemd-юниты"
scp -i "$KEY" "$(dirname "$0")/systemd/era-mb-game.service"          "$HOST:/tmp/"
scp -i "$KEY" "$(dirname "$0")/systemd/era-mb-game-sidekiq.service"  "$HOST:/tmp/"
run "sudo mv /tmp/era-mb-game.service /etc/systemd/system/ && \
     sudo mv /tmp/era-mb-game-sidekiq.service /etc/systemd/system/ && \
     sudo systemctl daemon-reload"

echo "== 4. nginx HTTP + ACME"
scp -i "$KEY" "$(dirname "$0")/nginx/era-mb-game.igroteh.su.conf" "$HOST:/tmp/era-mb-game.conf"
run "sudo cp /tmp/era-mb-game.conf /etc/nginx/sites-available/era-mb-game.igroteh.su && \
     sudo ln -sf /etc/nginx/sites-available/era-mb-game.igroteh.su /etc/nginx/sites-enabled/ && \
     sudo nginx -t && sudo systemctl reload nginx"

echo "== 5. Сертификат Let's Encrypt (запустится после того, как DNS укажет на сервер)"
echo "   Проверь DNS: dig +short era-mb-game.igroteh.su  → должен вернуть 62.173.148.168"
echo "   Затем выполни на сервере:"
echo "     sudo certbot --nginx -d era-mb-game.igroteh.su"
echo "   и раскатай https-конфиг: deploy/nginx_https_setup.sh"

echo "== Bootstrap base part done."
