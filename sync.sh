#!/usr/bin/env bash
# ==============================================================================
# Agent Skills Sync & Backup Tool
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WHITELIST_FILE="$SCRIPT_DIR/whitelist.txt"
SKILLS_DIR="$SCRIPT_DIR/skills"
FILES_DIR="$SCRIPT_DIR/files"
INVENTORY_FILE="$SCRIPT_DIR/external-skills.md"

SEARCH_DIRS=(
  "$HOME/.agents/skills"
  "$HOME/.claude/skills"
  "$HOME/.gemini/config/skills"
  "$HOME/.gemini/skills"
)

AGENT_LINK_DIRS=(
  "$HOME/.claude/skills"
  "$HOME/.gemini/skills"
  "$HOME/.gemini/config/skills"
  "$HOME/.gemini/antigravity/skills"
  "$HOME/.gemini/antigravity-cli/skills"
)

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

find_skill_source() {
  local name="$1"
  for base in "${SEARCH_DIRS[@]}"; do
    if [ -d "$base/$name" ]; then
      echo "$base/$name"
      return 0
    fi
  done
  return 1
}

# ------------------------------------------------------------------------------
# 1. Backup Custom Skills & Generate External Inventory
# ------------------------------------------------------------------------------
cmd_backup() {
  local push_git=false
  local commit_msg="chore: sync custom skills and update external inventory"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help|help)
        echo "Usage: ./sync.sh backup [--push [commit_message]]"
        return 0
        ;;
      --push)
        push_git=true
        if [[ $# -gt 1 && ! "$2" =~ ^-- ]]; then
          commit_msg="$2"
          shift
        fi
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  echo -e "${BLUE}=== Starting Skills Backup ===${NC}"
  mkdir -p "$SKILLS_DIR" "$FILES_DIR"

  if [ ! -f "$WHITELIST_FILE" ]; then
    echo -e "${RED}Error: whitelist.txt not found!${NC}"
    exit 1
  fi

  local custom_count=0
  local file_count=0

  while IFS= read -r item || [ -n "$item" ]; do
    # Skip comments and empty lines
    [[ -z "$item" || "$item" =~ ^[[:space:]]*# ]] && continue
    # Trim leading/trailing whitespace
    item="$(echo "$item" | xargs)"

    # Expand tilde
    local expanded_item="${item/#\~/$HOME}"

    if [[ "$expanded_item" == /* ]]; then
      # File / Directory path backup
      if [ -e "$expanded_item" ]; then
        local rel_item="${expanded_item#$HOME/}"
        rel_item="${rel_item#/}"
        local dest_path="$FILES_DIR/$rel_item"
        mkdir -p "$(dirname "$dest_path")"
        cp -R "$expanded_item" "$dest_path"
        echo -e "  ${GREEN}✓${NC} File: $rel_item"
        ((file_count++))
      else
        echo -e "  ${YELLOW}?${NC} Path not found locally: $item"
      fi
    else
      # Custom skill backup
      local skill_name="$item"
      local src
      if src="$(find_skill_source "$skill_name")"; then
        mkdir -p "$SKILLS_DIR/$skill_name"
        # Use rsync -aL to dereference symlinks so real files are stored in git
        rsync -aL --delete "$src/" "$SKILLS_DIR/$skill_name/"
        echo -e "  ${GREEN}✓${NC} Custom skill: $skill_name"
        ((custom_count++))
      elif [ -d "$SKILLS_DIR/$skill_name" ]; then
        echo -e "  ${BLUE}📦${NC} Preserved in repo (not currently installed): $skill_name"
        ((custom_count++))
      else
        echo -e "  ${RED}✗${NC} Skill not found on system or repo: $skill_name"
      fi
    fi
  done < "$WHITELIST_FILE"

  echo ""
  echo -e "${BLUE}=== Updating External Skills Inventory ===${NC}"
  generate_external_inventory

  echo ""
  echo -e "${GREEN}Backup complete!${NC} ($custom_count custom skills, $file_count files backed up)"

  if [ "$push_git" = true ]; then
    echo ""
    echo -e "${BLUE}=== Committing & Pushing to Git ===${NC}"
    cd "$SCRIPT_DIR"
    git add .
    if git diff --cached --quiet; then
      echo -e "${YELLOW}No changes detected. Working tree is clean.${NC}"
    else
      git commit -m "$commit_msg"
      echo -e "${GREEN}Pushing to remote origin...${NC}"
      git push origin HEAD
      echo -e "${GREEN}✓ Successfully pushed to git!${NC}"
    fi
  fi
}

# ------------------------------------------------------------------------------
# 2. Generate External Skills Inventory (Manifest / Reminder)
# ------------------------------------------------------------------------------
generate_external_inventory() {
  python3 - << 'EOF'
import os
import re
import datetime

script_dir = os.path.dirname(os.path.abspath(__file__)) if '__file__' in globals() else os.getcwd()
whitelist_file = os.path.join(script_dir, "whitelist.txt")
inventory_file = os.path.join(script_dir, "external-skills.md")

# Load whitelist items to exclude
whitelist_skills = set()
if os.path.exists(whitelist_file):
    with open(whitelist_file, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and not line.startswith("/") and not line.startswith("~"):
                whitelist_skills.add(line)

# Also exclude internal/system folders
ignore_names = {"synced", "tools", "__pycache__", ".git"}
ignore_names.update(whitelist_skills)

search_dirs = [
    os.path.expanduser("~/.agents/skills"),
    os.path.expanduser("~/.claude/skills"),
    os.path.expanduser("~/.gemini/config/skills"),
    os.path.expanduser("~/.gemini/skills")
]

external_skills = {}

for sdir in search_dirs:
    if not os.path.isdir(sdir):
        continue
    for entry in os.listdir(sdir):
        if entry.startswith(".") or entry in ignore_names:
            continue
        full_path = os.path.join(sdir, entry)
        if not os.path.isdir(full_path):
            continue
        
        # Read SKILL.md
        skill_file = os.path.join(full_path, "SKILL.md")
        desc = "No description available"
        if os.path.exists(skill_file):
            try:
                with open(skill_file, "r", encoding="utf-8", errors="ignore") as sf:
                    content = sf.read(4096)
                fm_match = re.search(r"^---\s*\n(.*?)\n---", content, re.DOTALL | re.MULTILINE)
                if fm_match:
                    fm = fm_match.group(1)
                    # Support multiline YAML folded block (>- or |)
                    m = re.search(r"^description:\s*(?:>[-+]?|\|[-+]?)?\s*\n?((?:[ \t]+[^\n]+\n?)+)", fm, re.MULTILINE)
                    if m:
                        raw_desc = " ".join(line.strip() for line in m.group(1).splitlines())
                    else:
                        m2 = re.search(r"^description:\s*(.*)", fm, re.MULTILINE)
                        raw_desc = m2.group(1).strip() if m2 else ""
                    
                    # Remove quotes and formatting for markdown table
                    raw_desc = raw_desc.strip("\"'").replace("\n", " ")
                    raw_desc = re.sub(r"[`*#|]", "", raw_desc).strip()
                    if len(raw_desc) > 115:
                        raw_desc = raw_desc[:112] + "..."
                    if raw_desc:
                        desc = raw_desc
            except Exception:
                pass
        
        display_path = full_path.replace(os.path.expanduser("~"), "~")
        if entry not in external_skills:
            external_skills[entry] = {
                "name": entry,
                "path": display_path,
                "desc": desc
            }

now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

with open(inventory_file, "w", encoding="utf-8") as f:
    f.write("# External Skills Inventory\n\n")
    f.write("> **Catatan**: File ini di-generate otomatis oleh `./sync.sh backup`.\n")
    f.write("> Berisi daftar skill pihak ketiga (third-party/upstream) yang terpasang di laptop kamu sebagai pengingat.\n")
    f.write("> Kodenya sengaja **tidak di-backup** ke repo ini agar tidak bloat & bisa di-install fresh dari upstream.\n\n")
    f.write(f"Terakhir diperbarui: **{now_str}** | Total: **{len(external_skills)} skills**\n\n")
    f.write("| Skill | Path Terpasang | Deskripsi Singkat |\n")
    f.write("| :--- | :--- | :--- |\n")
    
    for name in sorted(external_skills.keys()):
        item = external_skills[name]
        f.write(f"| `{item['name']}` | `{item['path']}` | {item['desc']} |\n")

print(f"  ✓ Recorded {len(external_skills)} external skills in external-skills.md")
EOF
}

# ------------------------------------------------------------------------------
# 3. Add a Custom Skill to Whitelist and Backup
# ------------------------------------------------------------------------------
cmd_add() {
  local skill_name="${1:-}"
  if [ -z "$skill_name" ]; then
    echo -e "${RED}Usage: ./sync.sh add <skill-name>${NC}"
    exit 1
  fi

  local src
  if ! src="$(find_skill_source "$skill_name")"; then
    echo -e "${YELLOW}Warning: Skill '$skill_name' not found in local skill folders.${NC}"
    read -p "Do you still want to add it to whitelist.txt? (y/n) " -n 1 -r
    echo ""
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
  fi

  # Check if already in whitelist
  if grep -qE "^[[:space:]]*${skill_name}[[:space:]]*$" "$WHITELIST_FILE" 2>/dev/null; then
    echo -e "${YELLOW}'$skill_name' is already in whitelist.txt.${NC}"
  else
    echo "$skill_name" >> "$WHITELIST_FILE"
    echo -e "${GREEN}✓ Added '$skill_name' to whitelist.txt${NC}"
  fi

  # Sync it immediately if source exists
  if [ -n "$src" ]; then
    mkdir -p "$SKILLS_DIR/$skill_name"
    rsync -aL --delete "$src/" "$SKILLS_DIR/$skill_name/"
    echo -e "${GREEN}✓ Backed up '$skill_name' into skills/$skill_name/${NC}"
  fi
}

# ------------------------------------------------------------------------------
# 4. Status Check
# ------------------------------------------------------------------------------
cmd_status() {
  echo -e "${BLUE}=== Custom Skills in Repo ===${NC}"
  if [ -d "$SKILLS_DIR" ]; then
    for s in "$SKILLS_DIR"/*; do
      [ -d "$s" ] || continue
      local sname
      sname="$(basename "$s")"
      local src
      if src="$(find_skill_source "$sname")"; then
        echo -e "  ${GREEN}✓${NC} $sname (active locally at $src)"
      else
        echo -e "  ${YELLOW}📦${NC} $sname (in repo only, not installed locally)"
      fi
    done
  fi

  echo ""
  echo -e "${BLUE}=== External Skills Tracked ===${NC}"
  if [ -f "$INVENTORY_FILE" ]; then
    local count
    count="$(grep -c '^| `' "$INVENTORY_FILE" 2>/dev/null || echo 0)"
    echo -e "  $count external skills recorded in external-skills.md"
  else
    echo -e "  external-skills.md not generated yet. Run './sync.sh backup'."
  fi

  echo ""
  echo -e "${BLUE}=== Git Status ===${NC}"
  cd "$SCRIPT_DIR"
  git status -s
}

# ------------------------------------------------------------------------------
# 5. Install / Restore Custom Skills & Link to All Agents
# ------------------------------------------------------------------------------
cmd_install() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
    echo "Usage: ./sync.sh install"
    return 0
  fi
  echo -e "${BLUE}=== Installing Custom Skills ===${NC}"
  local target_base="$HOME/.agents/skills"
  mkdir -p "$target_base"

  local installed_count=0
  if [ -d "$SKILLS_DIR" ]; then
    for s in "$SKILLS_DIR"/*; do
      [ -d "$s" ] || continue
      local sname
      sname="$(basename "$s")"
      local dest="$target_base/$sname"
      mkdir -p "$dest"
      rsync -a --delete "$s/" "$dest/"
      echo -e "  ${GREEN}✓${NC} Installed custom skill: $sname -> $dest"

      # Symlink to all agent environments
      for agent_dir in "${AGENT_LINK_DIRS[@]}"; do
        mkdir -p "$agent_dir"
        local link_target="$agent_dir/$sname"
        if [ ! -e "$link_target" ] && [ ! -L "$link_target" ]; then
          ln -s "$dest" "$link_target"
          echo -e "    ${BLUE}↳${NC} Linked to $agent_dir/$sname"
        fi
      done
      ((installed_count++))
    done
  fi

  echo ""
  echo -e "${BLUE}=== Restoring Config Files ===${NC}"
  local restored_files=0
  if [ -d "$FILES_DIR" ]; then
    cd "$FILES_DIR"
    find . -type f | while read -r f; do
      local rel="${f#./}"
      local target="$HOME/$rel"
      mkdir -p "$(dirname "$target")"
      cp "$f" "$target"
      echo -e "  ${GREEN}✓${NC} Restored: ~/$rel"
      ((restored_files++))
    done
    cd "$SCRIPT_DIR"
  fi

  echo ""
  echo -e "${GREEN}Installation & Linking complete!${NC}"
  echo -e "Custom skills are now available in Claude, Gemini, Antigravity, and OpenCode."
  if [ -f "$INVENTORY_FILE" ]; then
    echo -e "${YELLOW}💡 Tip:${NC} Check 'external-skills.md' if you need to reinstall your favorite upstream skills on this machine."
  fi
}

# ------------------------------------------------------------------------------
# Main Entry Point
# ------------------------------------------------------------------------------
usage() {
  echo "Usage: ./sync.sh <command> [options]"
  echo ""
  echo "Commands:"
  echo "  backup [--push [msg]]   Backup custom skills & update external skills inventory"
  echo "  add <skill-name>        Register a new custom skill and back it up immediately"
  echo "  status                  Check current status of repo vs local machine"
  echo "  install                 Restore custom skills & link to Claude, Gemini, Antigravity"
  echo "  help                    Show this help message"
  exit 0
}

case "${1:-}" in
  backup)
    shift
    cmd_backup "$@"
    ;;
  add)
    shift
    cmd_add "$@"
    ;;
  status)
    cmd_status
    ;;
  install)
    cmd_install
    ;;
  help|--help|-h|"")
    usage
    ;;
  *)
    echo -e "${RED}Unknown command: $1${NC}"
    usage
    ;;
esac
