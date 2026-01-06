#!/usr/bin/env bash

set -euo pipefail

if [ "$AUTHORIZATIONS" == "true" ]; then

  readonly GITHUB_KEYID_FILE="${ROOT_DIR}/.openpgp-keyid"
  readonly GITHUB_PUBKEY_FILE="${ROOT_DIR}/.openpgp-pubkey"

else

  readonly GITHUB_KEYID_FILE="${ROOT_DIR}/.infra/authorizations/.openpgp-keyid"
  readonly GITHUB_KEYID_FILE="${ROOT_DIR}/.infra/authorizations/.openpgp-pubkey"

fi

if gpg -k "${GITHUB_KEYID_FILE}" &>/dev/null; then
  exit 0
fi

gpg -q --import 2>/dev/null "${GITHUB_PUBKEY_FILE}"
