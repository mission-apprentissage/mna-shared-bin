#!/usr/bin/env bash

set -euo pipefail

ENV=${1:-}

if [ -z $ENV ]; then
  sops "${ROOT_DIR}/.infra/env.yml"
else
  sops "${ROOT_DIR}/.infra/env.$ENVIRONMENT.yml"
fi

