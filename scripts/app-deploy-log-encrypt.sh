#!/usr/bin/env bash

set -euo pipefail

readonly PASSPHRASE="${ROOT_DIR}/.bin/SEED_PASSPHRASE.txt"
readonly VAULT_FILE="${ROOT_DIR}/.infra/vault/vault.yml"

delete_cleartext() {
  if [ -f "$PASSPHRASE" ]; then
    shred -f -n 10 -u "$PASSPHRASE"
  fi
}
trap delete_cleartext EXIT

sops --decrypt --extract '["SEED_GPG_PASSPHRASE"]' .infra/env.yml > "$PASSPHRASE"

touch /tmp/deploy.log
gpg  -c --cipher-algo twofish --batch --passphrase-file "$PASSPHRASE" -o /tmp/deploy.log.gpg /tmp/deploy.log
