#!/usr/bin/env bash

set -euo pipefail

[[ -v _meta_help ]] || declare -A _meta_help
[[ -v _registry ]]  || declare -A _registry

function _register() {

  local cmd="$1"
  local fn="${2:-_shared_${1//[: ]/_}}"
  local help_var="${fn}__help"

  _meta_help["$cmd"]="${!help_var:-"(no description)"}"
  _registry["$cmd"]="$fn"

}

function _dispatch() {

  local cmd="${1:-}"
  
  if [[ -z "$cmd" ]]; then
    _help
    return 0
  fi

  shift
  local fn="${_registry[$cmd]:-}"

  if [[ -z "$fn" ]]; then
    echo "Err: Command '$cmd' not found" >&2
    _help
    return 1
  fi

  "$fn" "${@:-}"

}

function _help() {

  if [[ ${#_meta_help[@]} -eq 0 ]]; then
    echo "No commands registered."
    return 0
  fi

  mapfile -d '' sorted < <(printf '%s\0' "${!_meta_help[@]}" | sort -z)

  echo -e "Commands\n"

  for key in "${sorted[@]}"; do
    printf "%-30s %s\n" "${key}" "${_meta_help[$key]}"
  done

}

################################################################################
# Shared commands
################################################################################

_shared_app_deploy__help="Deploy application to <env>"
function _shared_app_deploy() {
  "${SCRIPTS_SHARED_DIR}/app-deploy.sh" "$@"
}

_shared_app_deploy_log_decrypt__help="Decrypt Github Actions Ansible logs"

function _shared_app_deploy_log_decrypt() {
  (cd "$ROOT_DIR" && "${SCRIPTS_SHARED_DIR}/app-deploy-log-decrypt.sh" "$@")
}

_shared_app_deploy_log_encrypt__help="Encrypt Github Actions Ansible logs"

function _shared_app_deploy_log_encrypt() {
  (cd "$ROOT_DIR" && "${SCRIPTS_SHARED_DIR}/app-deploy-log-encrypt.sh" "$@")
}

_shared_dev_dependencies_check__help="Check dependencies on system"

function _shared_dev_dependencies_check() {
  "${SCRIPTS_SHARED_DIR}/dev-dependencies-check.sh" "$@"
}

_shared_vault_edit__help="Edit SOPS env.global.yml or env.<env>.yml file"

function _shared_vault_edit() {
  editor=${EDITOR:-'code -w'}
  EDITOR=$editor "${SCRIPTS_SHARED_DIR}/vault-edit.sh" "$@"
}

_shared_docker_login__help="Login to ghcr.io"

function _shared_docker_login() {
  "${SCRIPTS_SHARED_DIR}/docker-login.sh" "$@"
}

_shared_seed_apply__help="Apply seed to a database"

function _shared_seed_apply() {
  "${SCRIPTS_SHARED_DIR}/seed-apply.sh" "$@"
}

_shared_seed_update__help="Update seed using a database"

function _shared_seed_update() {
  "${SCRIPTS_SHARED_DIR}/seed-update.sh" "$@"
}

_shared_dev_setup__help="Install binary with zsh completion on system"

function _shared_dev_setup() {

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

  _product-${PRODUCT_NAME}_completion "\$@"
  EOF

  printf '%s' "${message[@]#  }" >> /tmp/${PRODUCT_NAME}-zsh-completion

  sudo ln -fs "${ROOT_DIR}/.bin/mna" \
    /usr/local/bin/mna-${PRODUCT_NAME}

  sudo mkdir -p /usr/local/share/zsh/site-functions

  sudo install /tmp/${PRODUCT_NAME}-zsh-completion \
    /usr/local/share/zsh/site-functions/_mna-${PRODUCT_NAME}

  sudo rm -f ~/.zcompdump*

  rm /tmp/${PRODUCT_NAME}-zsh-completion

}

