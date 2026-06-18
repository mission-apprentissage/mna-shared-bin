#!/usr/bin/env bash

# Re-synchronise les destinataires des fichiers SOPS depuis le .sops.yaml du
# repo vers la métadonnée de chaque fichier (ajoute/révoque des accès).
#
# Usage :
#   sops:updatekeys                  # tous les .infra/env.*.yml
#   sops:updatekeys env.recette.yml  # un fichier précis
#   sops:updatekeys --yes ...        # non-interactif (pré-approuve)
#
# ATTENTION : re-chiffre la métadonnée (gros diff git). Vérifier le diff.

set -euo pipefail

YES=""
FILES=()

for arg in "$@"; do
  case "$arg" in
    -y|--yes) YES="--yes" ;;
    *) FILES+=("$arg") ;;
  esac
done

# Import best-effort des clés publiques du repo.
if [ -x "${SCRIPTS_SHARED_DIR}/gpg-import-github-pubkey.sh" ]; then
  "${SCRIPTS_SHARED_DIR}/gpg-import-github-pubkey.sh" 2>/dev/null || true
fi

if [ "${#FILES[@]}" -eq 0 ]; then
  shopt -s nullglob
  FILES=("${ROOT_DIR}"/.infra/env.*.yml)
  shopt -u nullglob
fi

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "Aucun fichier .infra/env.*.yml trouvé dans ${ROOT_DIR}." >&2
  exit 1
fi

for f in "${FILES[@]}"; do
  # Autorise un chemin relatif au repo ou absolu.
  [ -f "$f" ] || f="${ROOT_DIR}/.infra/$(basename "$f")"
  echo "→ sops updatekeys ${f#"$ROOT_DIR"/}"
  sops updatekeys $YES "$f"
done
