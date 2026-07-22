#!/usr/bin/env bash

# Gère les accès aux fichiers SOPS directement dans leurs métadonnées
# (aucun .sops.yaml requis) : rotation de la data key et ajout/retrait
# de destinataires PGP via `sops rotate`.
#
# Usage :
#   sops:rotate                                   # rotation simple, tous les .infra/env.*.yml
#   sops:rotate --add-pgp FP[,FP…] [fichier…]     # ajoute des destinataires
#   sops:rotate --rm-pgp FP[,FP…] [fichier…]      # révoque des destinataires
#
# ATTENTION : rotate régénère la data key → tout le ciphertext change
# (gros diff git). C'est inhérent, et souhaitable lors d'une révocation.

set -euo pipefail

ADD_PGP=""
RM_PGP=""
FILES=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --add-pgp) ADD_PGP="$2"; shift 2 ;;
    --rm-pgp) RM_PGP="$2"; shift 2 ;;
    *) FILES+=("$1"); shift ;;
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

ARGS=(--in-place)
[ -n "$ADD_PGP" ] && ARGS+=(--add-pgp "$ADD_PGP")
[ -n "$RM_PGP" ] && ARGS+=(--rm-pgp "$RM_PGP")

for f in "${FILES[@]}"; do
  # Autorise un chemin relatif au repo ou absolu.
  [ -f "$f" ] || f="${ROOT_DIR}/.infra/$(basename "$f")"
  echo "→ sops rotate ${f#"$ROOT_DIR"/}"
  sops rotate "${ARGS[@]}" "$f"
done
