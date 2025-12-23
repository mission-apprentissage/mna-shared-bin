#!/usr/bin/env bash

set -euo pipefail

if [ "$(git remote get-url origin)" == "git@github.com:mission-apprentissage/mna-shared-authorizations.git" ]; then
  export AUTHORIZATIONS=true
else
  export AUTHORIZATIONS=false
fi

function app:deploy() {
  "${SCRIPT_SHARED_DIR}/app-deploy.sh" "$@"
}

function app:deploy:log:encrypt() {
  (cd "$ROOT_DIR" && "${SCRIPT_SHARED_DIR}/app-deploy-log-encrypt.sh" "$@")
}

function app:deploy:log:decrypt() {
  (cd "$ROOT_DIR" && "${SCRIPT_SHARED_DIR}/app-deploy-log-decrypt.sh" "$@")
}

function vault:edit() {
  editor=${EDITOR:-'code -w'}
  EDITOR=$editor "${SCRIPT_SHARED_DIR}/vault-edit.sh" "$@"
}

function product:access:update() {
  editor=${EDITOR:-'code -w'}
  EDITOR=$editor "${SCRIPT_SHARED_DIR}/product-access-update.sh"
}

function seed:update() {
  "${SCRIPT_SHARED_DIR}/seed-update.sh" "$@"
}

function seed:apply() {
  "${SCRIPT_SHARED_DIR}/seed-apply.sh" "$@"
}

