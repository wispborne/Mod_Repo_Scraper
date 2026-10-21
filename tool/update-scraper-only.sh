#!/usr/bin/env bash
# Updates the scraper program and the website to the latest release and
# restarts the service. Does NOT scrape and does NOT publish.
# config.properties, qb_data/ and outputs/ are never touched.
#
# Usage: update-scraper-only.sh [--force | --rollback]
#   --force     update even when already on the latest build or a job is running
#   --rollback  put back the version this script last replaced

set -euo pipefail

SERVICE="starsector-scraper"
SERVER_URL="http://127.0.0.1:8085"
GITEA="https://git.wispborne.com"
REPO="david/Mod_Repo_Scraper"
# Gitea only lets signed-in users see anything, downloads included, so the
# script signs in with a token kept in this file beside it. Make one in Gitea
# under Settings > Applications, with read access to repositories, and keep
# the file readable by its owner only (chmod 600). The server reads it too, to
# offer updates in the viewer.
TOKEN_FILE=".gitea-token"
WAIT_SECONDS=30

# Everything a release replaces. Both programs and both page folders come from
# the same build, so they are swapped together or not at all.
ITEMS=(mod_repo_scraper mod_repo_scraper_server web site)
BACKUP=".update-backup"

mode=update
force=no
for arg in "$@"; do
  case "$arg" in
    --force) force=yes ;;
    --rollback) mode=rollback ;;
    -h | --help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

say() { printf '%s\n' "$*"; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

# Reads the build number out of a version.json file, or prints nothing.
build_in() { grep -o '"build":[0-9]*' "$1" 2>/dev/null | cut -d: -f2 || true; }

# Work in the folder this script sits in, wherever it was started from. The
# programs find qb_data/ and outputs/ by looking in the folder they start in.
cd "$(dirname "$(readlink -f "$0")")"
say "Running as $(whoami) in $(pwd)"

for cmd in curl tar sudo systemctl; do
  command -v "$cmd" >/dev/null || fail "$cmd is not installed."
done

# systemd says "started" as soon as the program starts, not when it is
# listening. Wait for it to answer, and give up early if systemd says it died.
wait_until_up() {
  local i
  for ((i = 0; i < WAIT_SECONDS; i++)); do
    if curl -fsS --max-time 2 "$SERVER_URL/api/version" >/dev/null 2>&1; then
      return 0
    fi
    if systemctl is-failed --quiet "$SERVICE"; then
      return 1
    fi
    sleep 1
  done
  return 1
}

# Puts every saved item back. Anything with no saved copy is left alone.
restore() {
  local item
  for item in "${ITEMS[@]}"; do
    if [[ -e $BACKUP/$item ]]; then
      rm -rf "$item"
      mv "$BACKUP/$item" .
    fi
  done
  rm -rf "$BACKUP"
}

restart_and_check() {
  sudo systemctl start "$SERVICE"
  wait_until_up
}

show_recent_log() {
  say "Last lines of the service log:"
  sudo journalctl -u "$SERVICE" -n 30 --no-pager || true
}

# --- Rolling back ------------------------------------------------------------

if [[ $mode == rollback ]]; then
  [[ -d $BACKUP ]] || fail "There is no saved previous version in $BACKUP."
  sudo systemctl stop "$SERVICE"
  restore
  if restart_and_check; then
    say "Rolled back to v$(build_in site/version.json). The server is up and answering."
    exit 0
  fi
  show_recent_log
  fail "Rolled back, but the server is not answering. Check: systemctl status $SERVICE"
fi

# --- Is there anything to do? ------------------------------------------------

[[ -s $TOKEN_FILE ]] ||
  fail "There is no Gitea token in $TOKEN_FILE. Gitea only lets signed-in users download releases. Nothing was changed."
AUTH="Authorization: token $(tr -d '[:space:]' <"$TOKEN_FILE")"

installed=$(build_in site/version.json)
# Gitea names the newest published release. Its tag is v<N>, where N is the
# build number.
latest=$(curl -fsS --max-time 15 -H "$AUTH" "$GITEA/api/v1/repos/$REPO/releases/latest" |
  grep -o '"tag_name":"v[0-9]*"' | grep -o '[0-9][0-9]*' || true)
[[ -n $latest ]] ||
  fail "Could not ask Gitea which release is the newest. Is the token in $TOKEN_FILE still good? Nothing was changed."

if [[ $installed == "$latest" && $force == no ]]; then
  say "Already on the latest build, v$latest. Nothing to do. (--force updates anyway.)"
  exit 0
fi
say "Installed: ${installed:+v}${installed:-unknown}. Latest: v$latest."

# A restart stops the job that is running and forgets the ones waiting.
status=$(curl -fsS --max-time 5 "$SERVER_URL/api/manager/status" 2>/dev/null || true)
if [[ $status == *'"managerOn":true'* ]] &&
  [[ $status != *'"current":null'* || $status != *'"queued":[]'* ]]; then
  if [[ $force == no ]]; then
    fail "A job is running or waiting. Restarting would stop it. Wait for it to finish, or use --force."
  fi
  say "A job is running or waiting. Going ahead anyway because of --force."
fi

# --- Download and check, while the old version keeps running -----------------

# Kept in this folder rather than /tmp so the swap below is a rename on the
# same disk, never a slow copy.
staging=$(mktemp -d "$PWD/.update.XXXXXX")
trap 'rm -rf "$staging"' EXIT
mkdir "$staging/new"

fetch() {
  # -f so an error page is a failure rather than something saved as the program.
  # Gitea sends a token it turns down to the sign-in page instead of refusing
  # it, so a bad token saves a web page here. The checks below catch that.
  curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 -H "$AUTH" -o "$2" "$1"
}

release="$GITEA/$REPO/releases/download/v$latest"
say "Downloading v$latest..."
fetch "$release/mod_repo_scraper" "$staging/new/mod_repo_scraper" ||
  fail "Could not download the scraper. Nothing was changed."
fetch "$release/mod_repo_scraper_server.tar.gz" "$staging/server.tar.gz" ||
  fail "Could not download the server. Nothing was changed."

[[ $(head -c4 "$staging/new/mod_repo_scraper") == $'\x7fELF' ]] ||
  fail "The scraper download is not a Linux program. Nothing was changed."
tar -xzf "$staging/server.tar.gz" -C "$staging/new" ||
  fail "The server download is damaged. Nothing was changed."
for item in "${ITEMS[@]}"; do
  [[ -e $staging/new/$item ]] || fail "The release is missing $item. Nothing was changed."
done
chmod +x "$staging/new/mod_repo_scraper" "$staging/new/mod_repo_scraper_server"
new_build=$(build_in "$staging/new/site/version.json")

# --- Swap and restart ---------------------------------------------------------

# Moves the current version into $BACKUP and the new one into place. Written
# with explicit returns because set -e does not apply inside an `if` test.
swap_in() {
  local item
  rm -rf "$BACKUP" && mkdir "$BACKUP" || return 1
  for item in "${ITEMS[@]}"; do
    if [[ -e $item ]]; then
      mv "$item" "$BACKUP/" || return 1
    fi
    mv "$staging/new/$item" . || return 1
  done
}

# The server has to let go before its program can be replaced, and one left
# running would keep serving the code it started with.
sudo systemctl stop "$SERVICE"

if ! swap_in; then
  say "Could not put the new version in place. Putting the old one back."
  restore
  restart_and_check || true
  fail "Update abandoned."
fi

if restart_and_check; then
  running=$(curl -fsS --max-time 2 "$SERVER_URL/api/version" 2>/dev/null |
    grep -o '"build":[0-9]*' | cut -d: -f2 || true)
  if [[ -n $new_build && -n $running && $running != "$new_build" ]]; then
    say "Warning: installed v$new_build, but the server says it is v$running."
  fi
  say "Updated to v${new_build:-?}. The server is up and answering."
  say "The previous version is saved in $BACKUP. Run with --rollback to go back to it."
  exit 0
fi

say "The new version did not start answering within ${WAIT_SECONDS} seconds."
show_recent_log
say "Putting the previous version back."
sudo systemctl stop "$SERVICE"
restore
if restart_and_check; then
  fail "Update failed. The previous version is running again."
fi
fail "Update failed, and the previous version is not answering either. Check: systemctl status $SERVICE"
