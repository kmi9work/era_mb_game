#!/usr/bin/env bash
# Ручной деплой era_mobile_api на epoha-сервер (deploy@62.173.148.168).
# Обычный путь — push в main (см. .github/workflows/deploy.yml); этот скрипт для
# локального деплоя/отладки. Использование: ./deploy/deploy.sh [<ref>]
set -euo pipefail

HOST=deploy@62.173.148.168
KEY=${KEY:-$HOME/.ssh/id_ed25519}
REF=${1:-main}
APP=/opt/era/era_mb_game
REPO=$APP/repo

ssh -i "$KEY" "$HOST" "
  set -e
  cd $REPO && git fetch origin --prune
  git checkout -q origin/$REF 2>/dev/null || git checkout -q $REF
  STAMP=\$(date +%Y%m%d%H%M%S)
  REL=$APP/releases/\$STAMP
  mkdir -p \$REL $APP/shared/{log,pids,storage,bundle,certs}

  # rsync-подобный хардкопи рабочего дерева (без .git)
  rsync -a --delete --exclude .git --exclude node_modules \
    $REPO/era_mobile_api/ \$REL/

  # shared-симлинки
  ln -sfn $APP/shared/log     \$REL/log
  ln -sfn $APP/shared/storage \$REL/storage
  ln -sfn $APP/shared/bundle  \$REL/vendor_bundle 2>/dev/null || true

  # env-файл приложения
  ln -sfn $APP/shared/era_mb_game.env \$REL/.env.production

  echo \"RELEASE=\$STAMP\" > $APP/releases/current_name
"
echo "release prepared: $(ssh -i "$KEY" "$HOST" 'cat /opt/era/era_mb_game/releases/current_name')"
