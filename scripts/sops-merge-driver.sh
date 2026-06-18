#!/usr/bin/env bash

# Git merge driver pour les fichiers chiffrés SOPS (.infra/env.*.yml).
#
# Déchiffre les trois versions (base/ours/theirs), fusionne le clair avec
# git merge-file, puis re-chiffre le résultat via les creation_rules du
# .sops.yaml du repo (sops encrypt --filename-override).
#
# Configuré par scripts/sops-git-setup.sh :
#   merge.sops.driver = .../sops-merge-driver.sh %O %A %B %P
#
# Args (fournis par git) :
#   $1 = %O  fichier ancêtre (base)
#   $2 = %A  fichier courant (ours) — DOIT contenir le résultat fusionné
#   $3 = %B  fichier entrant (theirs)
#   $4 = %P  chemin réel du fichier dans l'arbre (pour matcher .sops.yaml)

set -uo pipefail

BASE="$1"
OURS="$2"
THEIRS="$3"
FILEPATH="${4:-$2}"

# Import best-effort des clés publiques du repo (ne bloque pas la fusion).
if [ -n "${SCRIPTS_SHARED_DIR:-}" ] && [ -x "${SCRIPTS_SHARED_DIR}/gpg-import-github-pubkey.sh" ]; then
  "${SCRIPTS_SHARED_DIR}/gpg-import-github-pubkey.sh" 2>/dev/null || true
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# Déchiffrement des trois versions.
# --filename-override : git fournit des fichiers temporaires SANS extension ;
# on force le type (input + output) via le chemin réel, sinon sops ne sait pas
# parser le YAML.
# IMPORTANT : on n'autorise PAS de fallback sur du ciphertext pour ours/theirs.
# Si le déchiffrement échoue (clés manquantes, fichier corrompu), on échoue franchement
# plutôt que de fusionner/rechiffrer du chiffré (résultat silencieusement faux).
# Seul l'ancêtre peut être légitimement vide (add/add sans base commune).
if [ -s "$BASE" ]; then
  sops decrypt --filename-override "$FILEPATH" "$BASE" > "$TMPDIR/base" 2>/dev/null || {
    echo "sops-merge-driver: impossible de déchiffrer l'ancêtre de $FILEPATH" >&2
    exit 1
  }
else
  : > "$TMPDIR/base"
fi

sops decrypt --filename-override "$FILEPATH" "$OURS" > "$TMPDIR/ours" 2>/dev/null || {
  echo "sops-merge-driver: impossible de déchiffrer la version courante (ours) de $FILEPATH — clés manquantes ?" >&2
  exit 1
}

sops decrypt --filename-override "$FILEPATH" "$THEIRS" > "$TMPDIR/theirs" 2>/dev/null || {
  echo "sops-merge-driver: impossible de déchiffrer la version entrante (theirs) de $FILEPATH — clés manquantes ?" >&2
  exit 1
}

# Fusion 3-way sur le clair. git merge-file écrit dans "$TMPDIR/ours"
# et renvoie un code != 0 s'il reste des conflits.
git merge-file -L ours -L base -L theirs "$TMPDIR/ours" "$TMPDIR/base" "$TMPDIR/theirs"
merge_status=$?

if [ "$merge_status" -eq 0 ]; then
  # Fusion propre → re-chiffrement dans %A via le .sops.yaml du repo.
  if sops encrypt --filename-override "$FILEPATH" "$TMPDIR/ours" > "$OURS" 2>/dev/null; then
    exit 0
  fi
  echo "sops-merge-driver: échec du re-chiffrement de $FILEPATH (manque .sops.yaml ou clés ?)" >&2
  merge_status=1
fi

# Conflit (ou échec de re-chiffrement) : exposer le clair-avec-marqueurs
# à côté du fichier pour résolution manuelle, puis re-chiffrement.
conflict_file="${FILEPATH}.decrypted-conflict"
cp "$TMPDIR/ours" "$conflict_file"
{
  echo "sops-merge-driver: conflit non résolu dans $FILEPATH"
  echo "  → clair exposé dans : $conflict_file"
  echo "  1. résoudre les marqueurs <<<<<<< ======= >>>>>>> dans ce fichier"
  echo "  2. sops encrypt --filename-override $FILEPATH $conflict_file > $FILEPATH"
  echo "  3. rm $conflict_file && git add $FILEPATH"
} >&2

exit 1
