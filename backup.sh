#!/bin/bash
set -e

DEST_DIR="$(pwd)/skills"
FILES_DEST_DIR="$(pwd)/files"

mkdir -p "$DEST_DIR"
mkdir -p "$FILES_DEST_DIR"

if [ ! -f "whitelist.txt" ]; then
    echo "Error: whitelist.txt not found."
    exit 1
fi

while IFS= read -r item; do
    # Skip empty lines and comments
    if [[ -z "$item" ]] || [[ "$item" == \#* ]]; then
        continue
    fi
    
    # Expand tilde to HOME directory
    item="${item/#\~/$HOME}"
    
    if [[ "$item" == /* ]]; then
        # It's an absolute path
        if [ -e "$item" ]; then
            echo "Backing up file/dir: $item"
            # Preserve directory structure inside the 'files' folder
            TARGET_PATH="$FILES_DEST_DIR${item}"
            mkdir -p "$(dirname "$TARGET_PATH")"
            cp -R "$item" "$TARGET_PATH"
        else
            echo "Warning: Path '$item' not found."
        fi
    else
        # It's a skill name
        SOURCE_DIR="$HOME/.agents/skills"
        if [ -d "$SOURCE_DIR/$item" ]; then
            echo "Backing up skill: $item"
            cp -R "$SOURCE_DIR/$item" "$DEST_DIR/"
        else
            echo "Warning: Skill '$item' not found in $SOURCE_DIR"
        fi
    fi
done < "whitelist.txt"

echo "Backup complete!"
