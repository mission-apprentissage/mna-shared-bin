#!/usr/bin/env bash

set -euo pipefail

readonly PASSPHRASE=$(sops --decrypt --extract '["SEED_GPG_PASSPHRASE"]' .infra/env.global.yml)

touch /tmp/deploy.log

gpg -c --cipher-algo twofish --batch --passphrase "${PASSPHRASE}" -o /tmp/deploy.log.gpg /tmp/deploy.log
