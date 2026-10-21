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

rm -f /tmp/deploy.log.gpg

gh run download "$RUN_ID" -n "logs-$JOB_ID" -D /tmp

PASSPHRASE="$(sops --decrypt --extract '["SEED_GPG_PASSPHRASE"]' .infra/env.global.yml)"
readonly PASSPHRASE

if [ -z "${PASSPHRASE}" ]; then
  echo "SEED_GPG_PASSPHRASE vide, abandon du déchiffrement des journaux." >&2
  exit 1
fi

printf '%s' "${PASSPHRASE}" | gpg --batch --pinentry-mode loopback \
  --passphrase-fd 0 --decrypt /tmp/deploy.log.gpg
