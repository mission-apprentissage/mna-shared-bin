#!/usr/bin/env bash

set -euo pipefail

dependencies=(
  "ansible"
  "bash"
  "gpg"
  "sops"
  "node"
  "shred"
  "yq"
)

for command in "${dependencies[@]}"; do
  if ! type -p "$command" > /dev/null; then
    echo "$command missing !"
    exit 1
  fi
done

