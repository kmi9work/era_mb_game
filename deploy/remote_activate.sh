#!/usr/bin/env bash
# Активация release на сервере: bundle install (если нужно), миграции, сиды, рестарт сервисов.
# Вызывается из deploy.yml после подготовки release-директории. Использование:
#   ./deploy/remote_activate.sh <release_dir_name>
set -euo pipefail
HOST=deploy@62.173.148.168
KEY=${KEY:-$HOME/.ssh/id_ed25519}
APP=/opt/era/era_mb_game
REL=$APP/releases/$1

ssh -i "$KEY" "$HOST" "
  set -e
  export PATH=\"\$HOME/.rbenv/bin:\$PATH\"
  eval \"\$(rbenv init -)\"
  cd $REL

  echo '== bundle install (shared path)'
  bundle config set --local path $APP/shared/bundle
  bundle install --quiet

  echo '== migrations'
  bin/rails db:migrate

  echo '== seeds (идемпотентны)'
  bin/rails db:seed

  echo '== switch current symlink'
  ln -sfn $REL $APP/current

  # puma/sidekiq требуют пароль sudo — их перезапускает CI-джоба через secrets.DEPLOY_PASSWORD,
  # либо вручную: sudo systemctl restart era-mb-game era-mb-game-sidekiq
"
echo "activated: $1"
