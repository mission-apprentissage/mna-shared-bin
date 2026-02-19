#!/usr/bin/env bash

set -euo pipefail

declare -A _meta_help

_meta_help["app:deploy <env> [--user <username>]"]="Deploy application to <env>"

function app:deploy() {
  "${SCRIPT_SHARED_DIR}/app-deploy.sh" "$@"
}

_meta_help["app:deploy:log:decrypt"]="Decrypt Github Actions Ansible logs"

function app:deploy:log:decrypt() {
  (cd "$ROOT_DIR" && "${SCRIPT_SHARED_DIR}/app-deploy-log-decrypt.sh" "$@")
}

_meta_help["app:deploy:log:encrypt"]="Encrypt Github Actions Ansible logs"

function app:deploy:log:encrypt() {
  (cd "$ROOT_DIR" && "${SCRIPT_SHARED_DIR}/app-deploy-log-encrypt.sh" "$@")
}

_meta_help["dev:setup"]="Install mna-${PRODUCT_NAME} binary with zsh completion on system"

function dev:setup() {

  mapfile -d '' sorted < <(printf '%s\0' "${!_meta_help[@]}" | sort -z)

  readarray message <<"  EOF"
  #compdef -d mna-${PRODUCT_NAME}

  _mna-${PRODUCT_NAME}_completion() {
    local curcontext="\$curcontext" state line
    typeset -A opt_args
    local -a commands=(
  EOF

  printf '%s' "${message[@]#  }" > /tmp/${PRODUCT_NAME}-zsh-completion

  for key in "${sorted[@]}"; do
    echo "    ${key}:'${_meta_help[$key]}'" >> /tmp/${PRODUCT_NAME}-zsh-completion
  done

  readarray message <<"  EOF"
    )

    # Set completion behavior based on the current word
    _arguments -C '1: :->command'

    case \$state in
      (command)
        # Provide completion for commands
        _describe 'command' commands
        ;;
    esac

    # _describe 'command' commands
  }

  _mna-${PRODUCT_NAME}_completion "\$@"
  EOF

  printf '%s' "${message[@]#  }" >> /tmp/${PRODUCT_NAME}-zsh-completion

  sudo ln -fs "${ROOT_DIR}/.bin/mna-${PRODUCT_NAME}" \
    /usr/local/bin/mna-${PRODUCT_NAME}

  sudo mkdir -p /usr/local/share/zsh/site-functions

  sudo install /tmp/${PRODUCT_NAME}-zsh-completion \
    /usr/local/share/zsh/site-functions/_mna-${PRODUCT_NAME}

  sudo rm -f ~/.zcompdump*

  rm /tmp/${PRODUCT_NAME}-zsh-completion

}

_meta_help["dev:dependencies:check"]="Check dependencies on system"

function dev:dependencies:check() {
  "${SCRIPT_SHARED_DIR}/dev-dependencies-check.sh" "$@"
}

_meta_help["docker:login"]="Login to ghcr.io"

function docker:login() {
  "${SCRIPT_SHARED_DIR}/docker-login.sh" "$@"
}

_meta_help["product:access:update"]="Update product access"

function product:access:update() {
  editor=${EDITOR:-'code -w'}
  EDITOR=$editor "${SCRIPT_SHARED_DIR}/product-access-update.sh"
}

_meta_help["seed:apply"]="Apply seed to a database"

function seed:apply() {
  "${SCRIPT_SHARED_DIR}/seed-apply.sh" "$@"
}

_meta_help["seed:update"]="Update seed using a database"

function seed:update() {
  "${SCRIPT_SHARED_DIR}/seed-update.sh" "$@"
}

_meta_help["vault:edit [<env>]"]="Edit SOPS env.global.yml or env.<env>.yml file"

function vault:edit() {
  editor=${EDITOR:-'code -w'}
  EDITOR=$editor "${SCRIPT_SHARED_DIR}/vault-edit.sh" "$@"
}

