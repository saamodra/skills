#!/usr/bin/env bash
# Backward-compatible wrapper for sync.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/sync.sh" backup "$@"
