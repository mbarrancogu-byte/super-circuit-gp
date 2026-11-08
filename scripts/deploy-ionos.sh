#!/usr/bin/env bash
# Sube el juego web a IONOS por SFTP (solo los archivos publicables).
# Uso: HOST=... USER=... PASS=... DIR=/ bash scripts/deploy-ionos.sh
set -euo pipefail
cd "$(dirname "$0")/.."
: "${HOST:?}" "${USER:?}" "${PASS:?}"
DIR="${DIR:-/}"

LFTP_PASSWORD="$PASS" lftp --env-password -u "$USER" "sftp://$HOST" <<LFTP
set sftp:auto-confirm yes
set net:max-retries 3
set net:timeout 30
mirror --reverse --only-newer --parallel=4 --verbose \
  --exclude-glob .git/ --exclude-glob .github/ --exclude-glob scripts/ \
  --exclude-glob android/ --exclude-glob _glb/ --exclude-glob godot/ \
  --exclude-glob '_*' --exclude-glob '*.bat' \
  --exclude-glob '*.py' --exclude-glob '*.md' --exclude-glob '*_bak.*' \
  --exclude-glob '*_orig.*' --exclude-glob .gitignore --exclude-glob .vercelignore \
  . "$DIR"
bye
LFTP
