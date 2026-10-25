#!/usr/bin/env bash
# Copies the production server's data down to this computer.
#
# A file is copied when the server's copy is newer than the one here, or when
# this computer does not have it. Files that are newer here are left alone,
# and files that only exist here are never deleted.
#
# What is copied: qb_data/, outputs/, the source caches (*_cache.json) and
# merge-debug.json. Never config.properties, .gitea-token or the program.
#
# Run it from Git Bash on Windows (it needs GNU tar and find), or any Linux.
#
# Usage: tool/pull-prod-data.sh [--dry-run] [--yes]
#   --dry-run  list what would be copied, copy nothing
#   --yes      do not ask before copying
#
# Settings you can change with environment variables:
#   PROD_HOST  user@host to sign in to   (default david@192.168.2.41)
#   PROD_DIR   the program's folder there (default /home/david/Applications/Starsector_Mod_Repo_Scraper)
#   LOCAL_DIR  the folder to copy into    (default: the repo this script is in)
#   SSH        the ssh command to use     (default ssh)

set -euo pipefail

PROD_HOST="${PROD_HOST:-david@192.168.2.41}"
PROD_DIR="${PROD_DIR:-/home/david/Applications/Starsector_Mod_Repo_Scraper}"
LOCAL_DIR="${LOCAL_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
SSH="${SSH:-ssh}"

# The folders and files that hold data. Globs are matched on the server.
DATA_PATHS='qb_data outputs *_cache.json merge-debug.json'

dry_run=no
ask=yes
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=yes ;;
    --yes) ask=no ;;
    -h | --help) sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

say() { printf '%s\n' "$*"; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

for cmd in tar find awk; do
  command -v "$cmd" >/dev/null || fail "$cmd is not installed."
done
tar --version 2>/dev/null | grep -q 'GNU tar' \
  || fail "This needs GNU tar. On Windows, run it from Git Bash."

cd "$LOCAL_DIR"

# A job running here would be writing to the same files.
[ -e qb_data/scraper.lock ] \
  && fail "A scraper job is running on this computer (qb_data/scraper.lock exists). Stop it first."

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

remote_dir_q="$(printf '%q' "$PROD_DIR")"

# One line per file: "<modified time in seconds> <size> <path>". The lock
# file is left out; it only means something on the machine that wrote it.
list_files() {
  local found=() p
  for p in $DATA_PATHS; do
    [ -e "$p" ] && found+=("$p")
  done
  [ ${#found[@]} -eq 0 ] && return 0
  find "${found[@]}" -type f ! -path qb_data/scraper.lock -printf '%T@ %s %p\n'
}

say "Reading the file list on $PROD_HOST..."
# The script goes in on stdin and runs under bash, whatever the login shell is.
$SSH "$PROD_HOST" bash -s > "$work/remote.txt" <<EOF \
  || fail "Could not read the file list from $PROD_HOST:$PROD_DIR."
cd $remote_dir_q || exit 3
if [ -e qb_data/scraper.lock ]; then echo LOCKED; cat qb_data/scraper.lock; exit 0; fi
$(declare -p DATA_PATHS)
$(declare -f list_files)
list_files
EOF

if head -n 1 "$work/remote.txt" | grep -q '^LOCKED$'; then
  say "A job is running on the server right now:"
  tail -n +2 "$work/remote.txt"
  fail "Try again once it has finished, or the copy may catch files half-written."
fi
[ -s "$work/remote.txt" ] || fail "The server has none of the data folders in $PROD_DIR."

list_files > "$work/local.txt"

# Pick the files to copy: missing here, newer on the server, or the same
# second but a different size (the server's copy wins a tie).
awk '
  # Whole seconds only: tar keeps no more than that, and the two file
  # systems store fractions differently.
  NR == FNR { p = substr($0, length($1) + length($2) + 3); t[p] = int($1); s[p] = $2; next }
  {
    p = substr($0, length($1) + length($2) + 3)
    m = int($1)
    if (!(p in t))                          { new++; bytes += $2; print p > want; next }
    if (m > t[p] || (m == t[p] && $2 != s[p])) { upd++; bytes += $2; print p > want; next }
    if (m < t[p]) newer_here++
  }
  END {
    printf "%d new, %d newer on the server, %d newer here (kept), %.1f MB to copy\n",
      new, upd, newer_here, bytes / 1048576 > summary
  }
' want="$work/want.txt" summary="$work/summary.txt" "$work/local.txt" "$work/remote.txt"
touch "$work/want.txt"

say "$(cat "$work/summary.txt")"
count="$(wc -l < "$work/want.txt" | tr -d ' ')"
if [ "$count" -eq 0 ]; then
  say "Nothing to copy. This computer is up to date."
  exit 0
fi

if [ "$dry_run" = yes ]; then
  say "Would copy:"
  sed 's/^/  /' "$work/want.txt"
  exit 0
fi

if [ "$ask" = yes ]; then
  read -r -p "Copy $count files over your local data? [y/N] " answer
  case "$answer" in y | Y | yes) ;; *) say "Nothing copied."; exit 0 ;; esac
fi

say "Copying $count files..."
# The file list goes up to the server and the files come back as one tar
# stream. tar keeps each file's modified time, so the next run compares
# correctly. --keep-newer-files is a second guard in case a local file
# changed while this was running.
$SSH "$PROD_HOST" "cd $remote_dir_q && tar -cf - --verbatim-files-from -T -" < "$work/want.txt" \
  | tar -xf - --keep-newer-files \
  || fail "The copy did not finish. Files already copied are kept; run it again to fetch the rest."

say "Done. Copied $count files into $LOCAL_DIR."
