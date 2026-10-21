#!/usr/bin/env bash

set -euo pipefail

PASSPHRASE="$(sops --decrypt --extract '["SEED_GPG_PASSPHRASE"]' .infra/env.global.yml)"
readonly PASSPHRASE

if [ -z "${PASSPHRASE}" ]; then
  echo "SEED_GPG_PASSPHRASE vide, abandon du chiffrement des journaux." >&2
  exit 1
fi

touch /tmp/deploy.log

printf '%s' "${PASSPHRASE}" | gpg --batch --yes --pinentry-mode loopback \
  --passphrase-fd 0 --symmetric --cipher-algo TWOFISH \
  --output /tmp/deploy.log.gpg /tmp/deploy.log
