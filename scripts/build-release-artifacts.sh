#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
VERSION_TAG=${1:-v0.0.0-dev}
OUTPUT_DIR=${2:-"$ROOT_DIR/dist"}

mkdir -p "$OUTPUT_DIR"

CHROME_ZIP_NAME="linux-do-sidepeek-${VERSION_TAG#v}-chrome.zip"
FIREFOX_XPI_NAME="linux-do-sidepeek-${VERSION_TAG#v}-firefox-unsigned.xpi"

echo "[build] $OUTPUT_DIR/$CHROME_ZIP_NAME"
(
  cd "$ROOT_DIR"
  zip -r "$OUTPUT_DIR/$CHROME_ZIP_NAME" manifest.json src >/dev/null
)

echo "[build] $OUTPUT_DIR/$FIREFOX_XPI_NAME"
(
  cd "$ROOT_DIR"
  zip -r "$OUTPUT_DIR/$FIREFOX_XPI_NAME" manifest.json src >/dev/null
)

echo "CHROME_ZIP_PATH=$OUTPUT_DIR/$CHROME_ZIP_NAME"
echo "FIREFOX_XPI_PATH=$OUTPUT_DIR/$FIREFOX_XPI_NAME"
