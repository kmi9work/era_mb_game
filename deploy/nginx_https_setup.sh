#!/usr/bin/env bash
# Выпускает LE-сертификат и раскатывает https-конфиг nginx.
# Запускается ПОСЛЕ того, как DNS era-mb-game.igroteh.su указывает на 62.173.148.168.
set -euo pipefail
HOST=deploy@62.173.148.168
KEY=${KEY:-$HOME/.ssh/id_ed25519}

ssh -t -i "$KEY" "$HOST" '
  set -e
  echo "== certbot (интерактивно: спросит пароль sudo)"
  sudo certbot --nginx -d era-mb-game.igroteh.su --non-interactive --agree-tos \
       --redirect --cert-name era-mb-game.igroteh.su || {
    echo "certbot упал — проверь DNS: dig +short era-mb-game.igroteh.su";
    exit 1;
  }
'

# HTTPS-конфиг: certbot уже вписал сертификаты в sites-available; наша версия добавляет
# /cable-локацию. Раскатываем её поверх и перезагружаем nginx.
scp -i "$KEY" "$(dirname "$0")/nginx/era-mb-game.igroteh.su.https.conf" "$HOST:/tmp/era-mb-game.https.conf"

ssh -t -i "$KEY" "$HOST" '
  set -e
  CERT=/etc/letsencrypt/live/era-mb-game.igroteh.su/fullchain.pem
  [ -f "$CERT" ] && sed -i "s|/etc/letsencrypt/live/era-mb-game.igroteh.su/fullchain.pem|$CERT|" /tmp/era-mb-game.https.conf
  # подставить реальные пути из certbot-конфа, если отличаются
  sudo cp /tmp/era-mb-game.https.conf /etc/nginx/sites-available/era-mb-game.igroteh.su
  sudo nginx -t && sudo systemctl reload nginx
  echo "HTTPS ready: https://era-mb-game.igroteh.su"
'
