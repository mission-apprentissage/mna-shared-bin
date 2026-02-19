#!/usr/bin/env bash

set -euo pipefail

if [ -z "${1:-}" ]; then
  read -p "Veuillez renseigner l'ID du run: " RUN_ID
else
  readonly RUN_ID="$1"
  shift
fi

if [ -z "${1:-}" ]; then
  read -p "Veuillez renseigner l'ID du job: " JOB_ID
else
  readonly JOB_ID="$1"
  shift
fi

readonly PASSPHRASE="$ROOT_DIR/.bin/SEED_PASSPHRASE.txt"

delete_cleartext() {
  if [ -f "$PASSPHRASE" ]; then
    shred -f -n 10 -u "$PASSPHRASE"
  fi
}
trap delete_cleartext EXIT

rm -f /tmp/deploy.log.gpg

gh run download "$RUN_ID" -n "logs-$JOB_ID" -D /tmp

sops --decrypt --extract '["SEED_GPG_PASSPHRASE"]' .infra/env.global.yml > "$PASSPHRASE"

gpg -d --batch --passphrase-file "$PASSPHRASE" /tmp/deploy.log.gpg
