#!/bin/bash

set -euo pipefail

# shellcheck disable=SC1090
source "/home/oleksii/.voron-backup-config"

: "${GITHUB_REPO:?GITHUB_REPO is not set}"
: "${GITHUB_BRANCH:?GITHUB_BRANCH is not set}"
: "${GITHUB_TOKEN:?GITHUB_TOKEN is not set}"
: "${CONFIG_FOLDER:?CONFIG_FOLDER is not set}"

export GITHUB_TOKEN
export GIT_ASKPASS="/home/oleksii/.local/bin/voron-github-askpass"
export GIT_TERMINAL_PROMPT=0

remote_url="https://github.com/${GITHUB_REPO}.git"
database_copy="${CONFIG_FOLDER}/moonraker-sql.db"

cleanup() {
  rm -f "$database_copy"
}
trap cleanup EXIT

version_message() {
  local label="$1"
  local folder="$2"

  if [[ -n "$folder" && -d "${folder/#\~/$HOME}/.git" ]]; then
    git -C "${folder/#\~/$HOME}" describe --always --tags --long 2>/dev/null || true
  else
    printf '%s' 'unavailable'
  fi
}

if [[ "$BACKUP_DATABASE" == "true" && -f "${DATABASE_FILE/#\~/$HOME}" ]]; then
  cp "${DATABASE_FILE/#\~/$HOME}" "$database_copy"
fi

git -C "$CONFIG_FOLDER" config user.name "$GIT_USER_NAME"
git -C "$CONFIG_FOLDER" config user.email "$GIT_USER_EMAIL"
git -C "$CONFIG_FOLDER" remote set-url origin "$remote_url"
git -C "$CONFIG_FOLDER" pull origin "$GITHUB_BRANCH" --no-rebase
git -C "$CONFIG_FOLDER" add .

if git -C "$CONFIG_FOLDER" diff --cached --quiet; then
  echo "No configuration changes to back up."
  exit 0
fi

current_date=$(date +"%Y-%m-%d %T")
git -C "$CONFIG_FOLDER" commit \
  -m "Autocommit from $current_date" \
  -m "Klipper version: $(version_message Klipper "$KLIPPER_FOLDER")" \
  -m "Moonraker version: $(version_message Moonraker "$MOONRAKER_FOLDER")"
git -C "$CONFIG_FOLDER" push origin "$GITHUB_BRANCH"
