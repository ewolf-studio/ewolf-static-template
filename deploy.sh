#!/usr/bin/env bash
# Déploiement du site statique vers le serveur SSH (conteneur nginx `coupe-du-monde-web`).
# Aucune dépendance externe : utilise uniquement ssh + tar (présents sur Windows 10/11).
# Stratégie : on envoie une archive dans un dossier de staging, puis on bascule (mirror,
# les fichiers supprimés localement disparaissent aussi côté serveur).
set -euo pipefail

cd "$(dirname "$0")"

# ---------------------------------------------------------------------------
# Chargement STRICT du .env (sécurité maximale) :
#   - lecture ligne à ligne, AUCUNE exécution de code (pas de `source`) ;
#   - seules les clés attendues sont acceptées (whitelist) ;
#   - guillemets optionnels retirés ; assignation via `printf -v` (pas d'eval).
# ---------------------------------------------------------------------------
load_env() {
  local file=".env" line key val
  [ -f "$file" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    # trim espaces de début/fin
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -z "$line" ] && continue          # ligne vide
    case "$line" in \#*) continue ;; esac   # commentaire
    case "$line" in *=*) ;; *) continue ;; esac  # doit être CLE=VALEUR
    key="${line%%=*}"; val="${line#*=}"
    # trim autour de la clé ET de la valeur
    key="${key#"${key%%[![:space:]]*}"}"; key="${key%"${key##*[![:space:]]}"}"
    val="${val#"${val%%[![:space:]]*}"}"; val="${val%"${val##*[![:space:]]}"}"
    # whitelist des clés — tout le reste est ignoré
    case "$key" in
      SSH_HOST|SSH_USER|SSH_PORT|SSH_PATH) ;;
      *) continue ;;
    esac
    # retire des guillemets englobants éventuels
    case "$val" in
      \"*\") val="${val#\"}"; val="${val%\"}" ;;
      \'*\') val="${val#\'}"; val="${val%\'}" ;;
    esac
    printf -v "$key" '%s' "$val"   # assignation sûre (pas d'eval)
  done < "$file"
}
load_env

# ---------------------------------------------------------------------------
# Config requise + validation stricte des formats (anti-injection).
# ---------------------------------------------------------------------------
SSH_PORT="${SSH_PORT:-22}"
: "${SSH_HOST:?manquant — copie .env.example en .env et renseigne SSH_HOST}"
: "${SSH_USER:?manquant — renseigne SSH_USER dans .env}"
: "${SSH_PATH:?manquant — renseigne SSH_PATH dans .env}"

die() { echo "✗ $1" >&2; exit 1; }
[[ "$SSH_PORT" =~ ^[0-9]{1,5}$ ]]                 || die "SSH_PORT invalide : « $SSH_PORT »"
[[ "$SSH_USER" =~ ^[A-Za-z0-9._-]+$ ]]            || die "SSH_USER invalide : « $SSH_USER »"
[[ "$SSH_HOST" =~ ^[A-Za-z0-9._-]+$ ]]            || die "SSH_HOST invalide : « $SSH_HOST »"
# Chemin distant : absolu, caractères sûrs uniquement (pas d'espace, quote, ; $ ` etc.)
[[ "$SSH_PATH" =~ ^/[A-Za-z0-9._/-]+$ ]]          || die "SSH_PATH invalide : « $SSH_PATH »"

DEST="${SSH_PATH%/}"         # sans slash final
STAGE="${DEST}.stage"
SRC="public"                 # seul le contenu du site est déployé
DRY="${1:-}"

# Options SSH durcies (pas d'interactif, pas de forwarding).
SSH=(ssh -p "$SSH_PORT" -o BatchMode=yes -o ClearAllForwardings=yes "${SSH_USER}@${SSH_HOST}")

echo "→ Source : ./${SRC}/  →  Cible : ${SSH_USER}@${SSH_HOST}:${DEST}"

if [ "$DRY" = "--dry" ] || [ "$DRY" = "-n" ]; then
  echo "→ [dry-run] fichiers qui seraient envoyés :"
  tar -cv -C "$SRC" . -f /dev/null
  exit 0
fi

echo "→ Envoi de l'archive vers le staging…"
"${SSH[@]}" "rm -rf '${STAGE}' && mkdir -p '${STAGE}'"
tar -czf - -C "$SRC" . | "${SSH[@]}" "tar xzf - -C '${STAGE}'"

# Bascule "en place" : on garde l'inode du dossier monté (bind mount Docker),
# on remplace seulement son contenu. Fenêtre de bascule < 1s.
echo "→ Bascule du contenu (en place, mount préservé)…"
"${SSH[@]}" "mkdir -p '${DEST}' && find '${DEST}' -mindepth 1 -delete && cp -a '${STAGE}/.' '${DEST}/' && rm -rf '${STAGE}'"

echo "✓ Déploiement terminé."
