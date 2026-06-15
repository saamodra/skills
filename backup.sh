#!/bin/bash
set -e

SOURCE_DIR="$HOME/.agents/skills"
DEST_DIR="$(pwd)/skills"

mkdir -p "$DEST_DIR"

if [ ! -f "skills.txt" ]; then
    echo "Error: skills.txt not found."
    exit 1
fi

while IFS= read -r skill; do
    # Skip empty lines and comments
    if [[ -z "$skill" ]] || [[ "$skill" == \#* ]]; then
        continue
    fi
    
    if [ -d "$SOURCE_DIR/$skill" ]; then
        echo "Backing up skill: $skill"
        cp -R "$SOURCE_DIR/$skill" "$DEST_DIR/"
    else
        echo "Warning: Skill '$skill' not found in $SOURCE_DIR"
    fi
done < "skills.txt"

echo "Backup complete!"
