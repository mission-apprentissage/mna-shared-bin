#!/usr/bin/env bash

set -euo pipefail

if [ -z "${1:-}" ]; then
  readonly TARGET_DB="mongodb://__system:password@localhost:27017/?authSource=local&directConnection=true"
else
  readonly TARGET_DB="$1"
fi

echo "Base de données cible: $TARGET_DB"

readonly SEED_GPG="$ROOT_DIR/.infra/files/configs/mongodb/seed.gpg"

readonly PASSPHRASE="$(sops \
                        --decrypt \
                        --extract '["SEED_GPG_PASSPHRASE"]' \
                        .infra/env.global.yml)"

gpg -d --batch --passphrase "$PASSPHRASE" "$SEED_GPG" \
    | docker compose -f "$ROOT_DIR/docker-compose.yml" exec -iT mongodb \
      mongorestore \
        --archive \
        --nsInclude="${PRODUCT_NAME}.*" \
        --uri="${TARGET_DB}" \
        --drop \
        --gzip

yarn build:dev
yarn cli migrations:up
yarn cli indexes:recreate
