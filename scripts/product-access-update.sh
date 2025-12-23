#!/usr/bin/env bash

set -euo pipefail

if [ "$AUTHORIZATIONS" == "true" ]; then
  readonly HABILITATIONS_FILE="${ROOT_DIR}/habilitations.yml"
else
  readonly HABILITATIONS_FILE="${ROOT_DIR}/.infra/authorizations/habilitations.yml"
fi

"${SCRIPT_SHARED_DIR}/gpg-import-github-pubkey.sh"

check_for_main_key_rotation () {

  local modified=false

 if [ "$AUTHORIZATIONS" == "true" ]; then
    local readonly GITHUB_KEYID_FILE="${ROOT_DIR}/.openpgp-keyid"
  else
    local readonly GITHUB_KEYID_FILE="${ROOT_DIR}/.infra/authorizations/.openpgp-keyid"
  fi

  if [ ! -f "$GITHUB_KEYID_FILE" ]; then
    echo "Le fichier $GITHUB_KEYID_FILE est manquant !"
    exit 1
  fi

  GITHUB_KEYID=$(head -n 1 .openpgp-keyid | awk '{print $1}')

  local recipients=("$GITHUB_KEYID")

  echo "Extraction des clés OpenPGP du fichier d'habilitations..."

  mapfile -t keys < <( \
    sops --decrypt "${HABILITATIONS_FILE}" \
    | sed -n '/gpg_keys/,/authorized_keys/p' \
    | grep -Ev "gpg_keys|authorized_keys" \
    | awk -F "-" '{print $2}' | tr -d ' ')

  for key in "${keys[@]}"; do
    recipients+=("$key")
  done

  for key in "${recipients[@]}"; do
    echo $key
  done

  echo "Récupération des clés OpenPGP depuis keyserver.ubuntu.com..."

  for key in "${keys[@]}"; do
    echo $key
    gpg --keyserver hkp://keyserver.ubuntu.com --quiet --recv-keys "$key"
  done

  echo "-------------------------------------------------------"

  for file in "$HABILITATIONS_FILE" .infra/env.*.yml; do

    if [ "$file" == "$HABILITATIONS_FILE" ] \
      && [ "$AUTHORIZATIONS" == "false" ]; then
      continue
    fi

    if [ "$file" != "$HABILITATIONS_FILE" ] \
      && [ "$AUTHORIZATIONS" == "true" ]; then
      continue
    fi

    if [ ! -f $file ]; then
      continue 
    fi

    echo "## Traitement du fichier $file"

    echo "Extraction des clés OpenPGP actuellement utilisées..."

    local previous_recipients=()

    while read key; do
      previous_recipients+=("$key")
    done < <(yq -r '.sops.pgp[].fp' "$file")

    for key in "${previous_recipients[@]}"; do
      echo $key
    done

    echo "Identification des clés OpenPGP à ajouter..."

    for keya in "${recipients[@]}"; do

      exist=false

      for keyb in "${previous_recipients[@]}"; do

        if [ "$keya" == "$keyb" ]; then
          exist=true
          break;
        fi

      done

      if [ "$exist" = false ]; then
        echo "Ajout de la clé $keya"
        sops -i --rotate --add-pgp $keya "$file" 2>/dev/null
        modified=true
      fi

    done 

    echo "Identification des clés OpenPGP à supprimer..."

    local recipients_to_remove=()

    for keya in "${previous_recipients[@]}"; do

      exist=false

      for keyb in "${recipients[@]}"; do

        if [ "$keya" == "$keyb" ]; then
          exist=true
          break;
        fi

      done

      if [ "$exist" = false ]; then
        echo "Suppression de la clé $keya"
        sops -i --rotate --rm-pgp $keya "$file" 2>/dev/null
        modified=true
      fi

    done 
    
    echo "-------------------------------------------------------"

  done 


  if [ "$AUTHORIZATIONS" == "true" ] \
    && [ "$modified" == "true" ]; then

    local readonly product=$(git rev-parse --abbrev-ref HEAD)

    echo "Il est nécessaire de réaliser les actions suivantes sur le dépôt Git du projet '$product'"
    echo
    echo "  $ .bin/mna-bal product:access:update"
    echo "  $ git commit -m \"chore: mise à jour des habilitations\" .infra/authorizations/habilitations.yml"
    echo "  $ git push"
  fi

}

HABILITATIONS_HASH=$(openssl dgst -sha256 -r "$HABILITATIONS_FILE" \
  | cut -d' ' -f 1)

sops "$HABILITATIONS_FILE"

HABILITATIONS_NEW_HASH=$(openssl dgst -sha256 -r "$HABILITATIONS_FILE" \
  | cut -d' ' -f 1)

if [ "$HABILITATIONS_HASH" != "HABILITATIONS_NEW_HASH" ]; then
  check_for_main_key_rotation
fi

