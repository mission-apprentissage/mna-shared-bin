#!/usr/bin/env bash

# Configure (localement, dans ce repo) le merge driver et le diff SOPS.
# À lancer une fois par clone — appelé automatiquement par l'init du repo.
#
# Repose sur :
#   - .gitattributes : `.infra/env.*.yml diff=sopsdiffer merge=sops`
#   - scripts/sops-merge-driver.sh (ce sous-module)
#   - un .sops.yaml à la racine du repo (creation_rules)

set -euo pipefail

DRIVER="${SCRIPTS_SHARED_DIR}/sops-merge-driver.sh"

git -C "${ROOT_DIR}" config merge.sops.name "sops merge driver"
git -C "${ROOT_DIR}" config merge.sops.driver "${DRIVER} %O %A %B %P"

# Diff lisible : git diff affiche le clair des fichiers SOPS.
git -C "${ROOT_DIR}" config diff.sopsdiffer.textconv "sops decrypt"

echo "Merge driver & diff SOPS configurés pour ${REPO_NAME:-$ROOT_DIR}."
