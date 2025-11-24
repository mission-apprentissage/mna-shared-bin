#!/usr/bin/env bash

set -euo pipefail

ENVIRONMENT=${1:-}

"${SCRIPT_SHARED_DIR}/gpg-import-github-pubkey.sh"

if [ -z $ENVIRONMENT ]; then
  sops "${ROOT_DIR}/.infra/env.global.yml"
else
  sops "${ROOT_DIR}/.infra/env.$ENVIRONMENT.yml"
fi

