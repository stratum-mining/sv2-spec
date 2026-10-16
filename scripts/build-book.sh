#!/bin/bash
#
# Builds the Stratum V2 specification as an mdbook.
#
# The spec chapters live at the repository root so they render on GitHub, so
# they are staged into book/src (together with book/SUMMARY.md) before running
# mdbook.
#
# Usage: ./scripts/build-book.sh [build|serve]   (default: build)

set -euo pipefail

cd "$(dirname "$0")/.."

BOOK_DIR="book"
SRC_DIR="$BOOK_DIR/src"

RED='\033[31m'
NC='\033[0m' # No Color

rm -rf "$SRC_DIR"
mkdir -p "$SRC_DIR/img" "$SRC_DIR/extensions"

cp README.md [0-9][0-9]-*.md "$SRC_DIR/"
cp extensions/*.md "$SRC_DIR/extensions/"
cp img/*.png "$SRC_DIR/img/"
cp "$BOOK_DIR/SUMMARY.md" "$SRC_DIR/"

# Every chapter must be listed in SUMMARY.md, otherwise mdbook silently skips it
# and links pointing to it break.
missing=0
for file in [0-9][0-9]-*.md extensions/*.md; do
    if ! grep -qF "]($file)" "$BOOK_DIR/SUMMARY.md"; then
        echo -e "${RED}$file is not listed in $BOOK_DIR/SUMMARY.md${NC}"
        missing=1
    fi
done
if [[ $missing -ne 0 ]]; then
    exit 1
fi

mdbook "${1:-build}" "$BOOK_DIR"
