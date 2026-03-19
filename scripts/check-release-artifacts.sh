#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <chrome-zip> <firefox-xpi>" >&2
  exit 1
fi

CHROME_ZIP=$1
FIREFOX_XPI=$2

assert_file() {
  local path=$1

  if [ ! -f "$path" ]; then
    echo "[artifact-check] missing file: $path" >&2
    exit 1
  fi
}

assert_archive_entry() {
  local archive_path=$1
  local entry_path=$2

  if ! unzip -Z1 "$archive_path" | grep -Fx "$entry_path" >/dev/null; then
    echo "[artifact-check] missing $entry_path in $archive_path" >&2
    exit 1
  fi
}

assert_file "$CHROME_ZIP"
assert_file "$FIREFOX_XPI"

echo "[artifact-check] chrome archive"
assert_archive_entry "$CHROME_ZIP" "manifest.json"
assert_archive_entry "$CHROME_ZIP" "src/content.js"
assert_archive_entry "$CHROME_ZIP" "src/content.css"

echo "[artifact-check] firefox archive"
assert_archive_entry "$FIREFOX_XPI" "manifest.json"
assert_archive_entry "$FIREFOX_XPI" "src/content.js"
assert_archive_entry "$FIREFOX_XPI" "src/content.css"

echo "[artifact-check] firefox gecko id"
unzip -p "$FIREFOX_XPI" manifest.json | jq -e '
  .browser_specific_settings.gecko.id
  | type == "string" and length > 0
' >/dev/null

echo "[artifact-check] ok"
