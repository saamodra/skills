#!/bin/bash
set -e

SOURCE_SKILLS_DIR="$(pwd)/skills"
SOURCE_FILES_DIR="$(pwd)/files"

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
        rel_item="${item#$HOME/}"
        rel_item="${rel_item#/}"
        
        BACKUP_PATH="$SOURCE_FILES_DIR/$rel_item"
        if [ -e "$BACKUP_PATH" ]; then
            echo "Installing file/dir: $item"
            mkdir -p "$(dirname "$item")"
            cp -R "$BACKUP_PATH" "$item"
        else
            echo "Warning: Backup for path '$item' not found in $SOURCE_FILES_DIR"
        fi
    else
        # It's a skill name
        DEST_DIR="$HOME/.agents/skills"
        mkdir -p "$DEST_DIR"
        if [ -d "$SOURCE_SKILLS_DIR/$item" ]; then
            echo "Installing skill: $item"
            cp -R "$SOURCE_SKILLS_DIR/$item" "$DEST_DIR/"
        else
            echo "Warning: Backup for skill '$item' not found in $SOURCE_SKILLS_DIR"
        fi
    fi
done < "whitelist.txt"

echo "Installation complete!"
