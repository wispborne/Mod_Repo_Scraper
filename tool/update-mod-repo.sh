#!/usr/bin/env bash
# Updates the scraper, scrapes the forum and publishes the results.
# Runs twice a day from cron.
#
# Needs update-scraper-only.sh in the same folder; it does the updating.
#
# Usage: update-mod-repo.sh [--no-update] [--no-publish]
#   --no-update   scrape with the version already installed
#   --no-publish  scrape, but do not push anything

set -euo pipefail

PUBLISH_REPO_URL="git@github.com:wispborne/StarsectorModRepo.git"
PUBLISH_DIR="StarsectorModRepo"

do_update=yes
do_publish=yes
for arg in "$@"; do
  case "$arg" in
    --no-update) do_update=no ;;
    --no-publish) do_publish=no ;;
    -h | --help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

# Cron keeps whatever is printed, so every line says when it happened.
say() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
fail() { say "Error: $*" >&2; exit 1; }

# Work in the folder this script sits in, wherever cron starts it from.
cd "$(dirname "$(readlink -f "$0")")"
say "Running as $(whoami) in $(pwd)"

for cmd in git curl flock; do
  command -v "$cmd" >/dev/null || fail "$cmd is not installed."
done

# One run at a time. A scrape can outlast the gap between two cron runs, and
# two at once would fight over outputs/ and the publish folder.
exec 9>.update-mod-repo.lock
flock -n 9 || fail "Another run of this script is still going. Skipping this one."

started=$SECONDS

# config.properties and qb_data/ live here and are never touched by this script.
# qb_data/ holds the scraped pages, the download results and the LLM answers:
# deleting it means scraping the whole forum again and paying for every LLM call
# a second time. outputs/ is different — it is rebuilt from qb_data/ every run.

# --- Update ------------------------------------------------------------------

# A failed update is not a reason to skip the scrape. The update script leaves
# the previous version in place and running when it fails, and yesterday's
# program scraping today is better than no scrape at all.
if [[ $do_update == yes ]]; then
  [[ -x ./update-scraper-only.sh ]] || fail "update-scraper-only.sh is missing or cannot be run."
  if ! ./update-scraper-only.sh; then
    say "The update did not go through. Scraping with the version already installed."
  fi
fi
[[ -x ./mod_repo_scraper ]] || fail "There is no scraper program here to run."

# --- Scrape ------------------------------------------------------------------

# Old outputs go: broken JSON in here makes the scraper fail when it tries to
# update it, and everything in here is rebuilt from qb_data/ anyway.
rm -rf outputs/

say "Scraping..."
./mod_repo_scraper || fail "The scraper failed. Not publishing."

# Check everything is there before anything is copied, so a half-finished run
# never publishes a half-finished website.
for file in outputs/ModRepo.json outputs/forum-data-bundle.json outputs/site/mods.json; do
  [[ -s $file ]] || fail "$file is missing or empty. Not publishing."
done
[[ -d outputs/site/mods ]] || fail "outputs/site/mods is missing. Not publishing."
[[ -d site ]] || fail "The website's own files (site/) are missing. Not publishing."

if [[ $do_publish == no ]]; then
  say "Done in $((SECONDS - started))s. Not publishing, because of --no-publish."
  exit 0
fi

# --- Publish -----------------------------------------------------------------

# Cloned after the scrape rather than before, so the copy we push on top of is
# minutes old rather than as old as the scrape is long.
say "Cloning $PUBLISH_REPO_URL..."
rm -rf "$PUBLISH_DIR"
git clone --quiet --depth 1 "$PUBLISH_REPO_URL" "$PUBLISH_DIR" ||
  fail "Could not clone the publish repo."

# The two main outputs.
cp outputs/*.json "$PUBLISH_DIR/"

# The website's own code, from the release this folder was updated to.
cp -a site/. "$PUBLISH_DIR/"

# The generated website data. The old mods/ folder goes first so mods that
# were removed do not stay online.
rm -rf "$PUBLISH_DIR/mods"
cp -a outputs/site/. "$PUBLISH_DIR/"

git -C "$PUBLISH_DIR" add -A

if git -C "$PUBLISH_DIR" diff --cached --quiet; then
  say "Nothing changed, so nothing to publish."
else
  build=$(grep -o '"build":[0-9]*' site/version.json 2>/dev/null | cut -d: -f2 || true)
  git -C "$PUBLISH_DIR" commit --quiet \
    -m "Auto-updated ModRepo.json, forum-data-bundle.json, & the website.${build:+ (scraper v$build)}"
  git -C "$PUBLISH_DIR" push --quiet || fail "Could not push to the publish repo."
  say "Published: $(git -C "$PUBLISH_DIR" diff --stat HEAD~1 HEAD 2>/dev/null | tail -n1 || echo 'one commit')."
fi

say "Done in $((SECONDS - started))s."
