#!/usr/bin/env bash

# Git merge driver pour les fichiers chiffrés SOPS (.infra/env.*.yml).
#
# Déchiffre les trois versions (base/ours/theirs), fusionne le clair avec
# git merge-file, puis ré-injecte le résultat dans le fichier chiffré courant
# via `sops edit` : les destinataires et la data key proviennent des
# métadonnées du fichier lui-même — aucun .sops.yaml requis. La data key est
# conservée, donc les valeurs non modifiées gardent un ciphertext identique
# (diff git minimal).
#
# Limite (comportement git standard) : deux variables sur des lignes
# adjacentes modifiées par deux branches produisent un conflit ; seules les
# modifications séparées d'au moins une ligne inchangée fusionnent seules.
#
# Configuré par scripts/sops-git-setup.sh :
#   merge.sops.driver = .../sops-merge-driver.sh %O %A %B %P
#
# Args (fournis par git) :
#   $1 = %O  fichier ancêtre (base)
#   $2 = %A  fichier courant (ours) — DOIT contenir le résultat fusionné
#   $3 = %B  fichier entrant (theirs)
#   $4 = %P  chemin réel du fichier dans l'arbre (messages + type)

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
# --input-type/--output-type : git fournit des fichiers temporaires SANS
# extension ; on force le type, sinon sops ne sait pas parser le YAML.
# IMPORTANT : on n'autorise PAS de fallback sur du ciphertext pour ours/theirs.
# Si le déchiffrement échoue (clés manquantes, fichier corrompu), on échoue franchement
# plutôt que de fusionner/rechiffrer du chiffré (résultat silencieusement faux).
# Seul l'ancêtre peut être légitimement vide (add/add sans base commune).
if [ -s "$BASE" ]; then
  sops decrypt --input-type yaml --output-type yaml "$BASE" > "$TMPDIR/base" 2>/dev/null || {
    echo "sops-merge-driver: impossible de déchiffrer l'ancêtre de $FILEPATH" >&2
    exit 1
  }
else
  : > "$TMPDIR/base"
fi

sops decrypt --input-type yaml --output-type yaml "$OURS" > "$TMPDIR/ours" 2>/dev/null || {
  echo "sops-merge-driver: impossible de déchiffrer la version courante (ours) de $FILEPATH — clés manquantes ?" >&2
  exit 1
}

sops decrypt --input-type yaml --output-type yaml "$THEIRS" > "$TMPDIR/theirs" 2>/dev/null || {
  echo "sops-merge-driver: impossible de déchiffrer la version entrante (theirs) de $FILEPATH — clés manquantes ?" >&2
  exit 1
}

# Fusion 3-way sur le clair. git merge-file écrit dans "$TMPDIR/ours"
# et renvoie un code != 0 s'il reste des conflits.
git merge-file -L ours -L base -L theirs "$TMPDIR/ours" "$TMPDIR/base" "$TMPDIR/theirs"
merge_status=$?

if [ "$merge_status" -eq 0 ]; then
  # Fusion propre → ré-injection du clair fusionné dans %A (toujours un
  # fichier SOPS valide) via sops edit : mêmes destinataires, même data key.
  # sops parse EDITOR en shellwords → `cp <chemin>` fonctionne tant que le
  # chemin mktemp ne contient pas d'espace.
  EDITOR="cp $TMPDIR/ours" sops edit --input-type yaml --output-type yaml "$OURS" 2>/dev/null
  rc=$?
  # 200 = fichier inchangé : le clair fusionné == ours, %A est déjà correct.
  if [ "$rc" -eq 0 ] || [ "$rc" -eq 200 ]; then
    exit 0
  fi
  echo "sops-merge-driver: échec du re-chiffrement de $FILEPATH (clé privée absente ou expirée ?)" >&2
  merge_status=1
fi

# Conflit (ou échec de re-chiffrement) : exposer le clair-avec-marqueurs
# à côté du fichier pour résolution manuelle, puis ré-injection.
conflict_file="${FILEPATH}.decrypted-conflict"
cp "$TMPDIR/ours" "$conflict_file"
{
  echo "sops-merge-driver: conflit non résolu dans $FILEPATH"
  echo "  → clair exposé dans : $conflict_file"
  echo "  1. résoudre les marqueurs <<<<<<< ======= >>>>>>> dans ce fichier"
  echo "  2. EDITOR=\"cp $conflict_file\" sops edit $FILEPATH"
  echo "  3. rm $conflict_file && git add $FILEPATH"
} >&2

exit 1
