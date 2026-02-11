#!/bin/bash

TEMPLATE="./scripts/README.template.md"
OUTFILE="README.md"
INDEX_TMP="$(mktemp)"
README_TMP="$(mktemp)"

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
NC='\033[0m' # No Color

# Generate the index
echo "" > "$INDEX_TMP"
for file in $(ls *.md | grep -v -i 'README.md' | sort); do
    while IFS= read -r line; do
        if [[ $line =~ ^(#+)[[:space:]]([0-9]+(\.[0-9]+)*)(\.[[:space:]]+|[[:space:]])(.*) ]]; then
            hashes="${BASH_REMATCH[1]}"
            number="${BASH_REMATCH[2]}"
            title="${BASH_REMATCH[5]}"
            level=$((${#hashes} - 1))
            indent=$(printf '%*s' $((level * 2)) " ")
            anchor=$(echo "$number-$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
            echo "${indent}- [$number. $title](./$file#$anchor)" >> "$INDEX_TMP"
        fi
    done < "$file"
done

# Replace [table_of_contents] with generated index
sed "/\[table_of_contents\]/{
    r $INDEX_TMP
    d
}" "$TEMPLATE" > "$README_TMP"

if [[ "$1" == "--check" ]]; then
    if ! diff --color=auto -u "$OUTFILE" "$README_TMP"; then
        echo -e "\n${RED}Table of Contents in README.md is out of date. Please run the script with --bless to update it.${NC}"
        rm "$INDEX_TMP" "$README_TMP"
        exit 1
    else
        echo -e "${GREEN}README.md Table of Contents is up to date.${NC}"
        rm "$INDEX_TMP" "$README_TMP"
        exit 0
    fi
elif [[ "$1" == "--bless" ]]; then
    mv "$README_TMP" "$OUTFILE"
    rm "$INDEX_TMP"
    echo -e "${YELLOW}README.md generated from template.${NC}"
else
    rm "$INDEX_TMP" "$README_TMP"
    echo -e "${GREEN}No changes made. Use --check to verify or --bless to update README.md.${NC}"
fi

