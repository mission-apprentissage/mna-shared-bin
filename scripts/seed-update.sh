#!/usr/bin/env bash

set -euo pipefail

if [ -z "${1:-}" ]; then
  readonly TARGET_DB="mongodb://__system:password@localhost:27017/?authSource=local&directConnection=true"
else
  readonly TARGET_DB="$1"
fi

echo "Base de données cible: $TARGET_DB"

read \
  -p "La base de données contient-elle des données sensibles ? [Y/n]: " \
  response

case $response in
  [nN][oO]|[nN])
    ;;
  *)
    exit 1
    ;;
esac

readonly SEED_GPG="$ROOT_DIR/.infra/files/configs/mongodb/seed.gpg"

readonly PASSPHRASE="$(sops \
                        --decrypt \
                        --extract '["SEED_GPG_PASSPHRASE"]' \
                        .infra/env.global.yml)"

docker compose -f "$ROOT_DIR/docker-compose.yml" up mongodb -d

mkdir -p "$ROOT_DIR/.infra/files/mongodb"

yarn build:dev
yarn cli migrations:up
yarn cli indexes:recreate

docker compose -f "$ROOT_DIR/docker-compose.yml" exec -iT mongodb \
  mongodump \
    --uri "$TARGET_DB" \
    --gzip \
    --archive \
    | gpg -c \
        --cipher-algo twofish \
        --batch \
        --passphrase "$PASSPHRASE" \
        -o "$SEED_GPG"

