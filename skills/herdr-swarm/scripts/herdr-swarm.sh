#!/usr/bin/env bash
# herdr-swarm.sh — Spawn and coordinate multiple AI coding agents in parallel using Herdr
# Part of the herdr-swarm skill

set -euo pipefail

usage() {
  cat << 'EOF'
Usage: herdr-swarm.sh [OPTIONS]

Options:
  --style <pane|tab>          Layout style: 'pane' (default, in current tab) or 'tab' (new tabs)
  --agent-kind <kind>         Herdr agent kind (default: agy)
  --agent-args <args>         Flags passed to the agent (default: --dangerously-skip-permissions)
  --worktree-mode <mode>      Worktree mode: 'herdr' (default), 'git', or 'none'
  --worktree-root <dir>       Root directory for new worktrees (default: auto-detected)
  --base <ref>                Base branch or git ref (default: main or current branch)
  --task <name|branch|prompt> Repeatable task definition (pipe-separated)
  --tasks-json <file|- >      JSON array of task objects [{"name":"..","branch":"..","prompt":".."}]
  --dry-run                   Print execution plan without making changes
  -h, --help                  Show this help message

Examples:
  herdr-swarm.sh --style pane \
    --task "a5-create|offline-sync/a5|Implement issue 31" \
    --task "r3-verify|offline-sync/r3|Verify issue 32"

  cat tasks.json | herdr-swarm.sh --style tab --tasks-json -
EOF
  exit 1
}

# 1. Verify HERDR_ENV
if [[ "${HERDR_ENV:-}" != "1" ]]; then
  echo "Error: herdr-swarm must run inside a Herdr-managed pane (HERDR_ENV=1)." >&2
  exit 1
fi

STYLE="pane"
AGENT_KIND="agy"
AGENT_ARGS="--dangerously-skip-permissions"
WORKTREE_MODE="herdr"
WORKTREE_ROOT=""
BASE_REF=""
DRY_RUN=0
declare -a TASK_SPECS=()
TASKS_JSON_INPUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --style)
      STYLE="$2"; shift 2 ;;
    --agent-kind)
      AGENT_KIND="$2"; shift 2 ;;
    --agent-args)
      AGENT_ARGS="$2"; shift 2 ;;
    --worktree-mode)
      WORKTREE_MODE="$2"; shift 2 ;;
    --worktree-root)
      WORKTREE_ROOT="$2"; shift 2 ;;
    --base)
      BASE_REF="$2"; shift 2 ;;
    --task)
      TASK_SPECS+=("$2"); shift 2 ;;
    --tasks-json)
      TASKS_JSON_INPUT="$2"; shift 2 ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    -h|--help)
      usage ;;
    *)
      echo "Unknown option: $1" >&2
      usage ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
REPO_NAME="$(basename "$REPO_ROOT")"

if [[ -z "$BASE_REF" ]]; then
  BASE_REF="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")"
  if [[ "$BASE_REF" == "HEAD" ]]; then
    BASE_REF="main"
  fi
fi

# Auto-detect worktree root if not provided
if [[ -z "$WORKTREE_ROOT" && "$WORKTREE_MODE" != "none" ]]; then
  if [[ -d "$HOME/orca/workspaces/$REPO_NAME" ]]; then
    WORKTREE_ROOT="$HOME/orca/workspaces/$REPO_NAME"
  elif [[ -d "$HOME/.worktrees/$REPO_NAME" ]]; then
    WORKTREE_ROOT="$HOME/.worktrees/$REPO_NAME"
  else
    WORKTREE_ROOT="$(dirname "$REPO_ROOT")/${REPO_NAME}-worktrees"
  fi
fi

# Parse tasks into arrays
declare -a TASK_NAMES=()
declare -a TASK_BRANCHES=()
declare -a TASK_PROMPTS=()

sanitize_name() {
  local raw="$1"
  local clean
  clean="$(echo "$raw" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_-' '-' | sed 's/^[0-9_-]*//' | cut -c 1-32 | sed 's/[-_]*$//')"
  if [[ -z "$clean" ]]; then
    clean="swarm-task-$RANDOM"
  fi
  echo "$clean"
}

if [[ -n "$TASKS_JSON_INPUT" ]]; then
  JSON_CONTENT=""
  if [[ "$TASKS_JSON_INPUT" == "-" ]]; then
    JSON_CONTENT="$(cat)"
  elif [[ -f "$TASKS_JSON_INPUT" ]]; then
    JSON_CONTENT="$(cat "$TASKS_JSON_INPUT")"
  else
    JSON_CONTENT="$TASKS_JSON_INPUT"
  fi

  TASK_COUNT="$(echo "$JSON_CONTENT" | jq '. | length')"
  for ((i=0; i<TASK_COUNT; i++)); do
    T_NAME="$(echo "$JSON_CONTENT" | jq -r ".[$i].name // empty")"
    T_BRANCH="$(echo "$JSON_CONTENT" | jq -r ".[$i].branch // empty")"
    T_PROMPT="$(echo "$JSON_CONTENT" | jq -r ".[$i].prompt // empty")"
    
    if [[ -z "$T_NAME" ]]; then
      T_NAME="task-$((i+1))"
    fi
    if [[ -z "$T_BRANCH" ]]; then
      T_BRANCH="swarm/$T_NAME"
    fi
    TASK_NAMES+=("$(sanitize_name "$T_NAME")")
    TASK_BRANCHES+=("$T_BRANCH")
    TASK_PROMPTS+=("$T_PROMPT")
  done
elif [[ ${#TASK_SPECS[@]} -gt 0 ]]; then
  for spec in "${TASK_SPECS[@]}"; do
    IFS='|' read -r r_name r_branch r_prompt <<< "$spec"
    if [[ -z "$r_branch" ]]; then
      r_branch="swarm/$r_name"
    fi
    TASK_NAMES+=("$(sanitize_name "$r_name")")
    TASK_BRANCHES+=("$r_branch")
    TASK_PROMPTS+=("${r_prompt:-}")
  done
else
  echo "Error: No tasks specified. Use --task or --tasks-json." >&2
  exit 1
fi

TOTAL_TASKS=${#TASK_NAMES[@]}
if [[ $TOTAL_TASKS -eq 0 ]]; then
  echo "Error: Task list is empty." >&2
  exit 1
fi

echo "=== Herdr Swarm Launch ==="
echo "Tasks: $TOTAL_TASKS"
echo "Style: $STYLE"
echo "Agent: $AGENT_KIND ($AGENT_ARGS)"
echo "Worktree Mode: $WORKTREE_MODE"
if [[ "$WORKTREE_MODE" != "none" ]]; then
  echo "Worktree Root: $WORKTREE_ROOT"
  echo "Base Ref: $BASE_REF"
fi
echo "=========================="

if [[ $DRY_RUN -eq 1 ]]; then
  echo "[Dry-Run] Plan:"
  for ((i=0; i<TOTAL_TASKS; i++)); do
    echo "  Task $((i+1)): name=${TASK_NAMES[$i]}, branch=${TASK_BRANCHES[$i]}"
    echo "    Prompt: ${TASK_PROMPTS[$i]}"
  done
  exit 0
fi

# Ensure worktree directory exists
if [[ "$WORKTREE_MODE" != "none" ]]; then
  mkdir -p "$WORKTREE_ROOT"
fi

CALLER_PANE_ID="${HERDR_PANE_ID:-}"
WORKSPACE_ID="${HERDR_WORKSPACE_ID:-}"
CURRENT_TAB_ID="${HERDR_TAB_ID:-}"

declare -a CREATED_PANES=()
declare -a CREATED_DIRS=()
declare -a CREATED_AGENTS=()

LAST_PANE_ID="$CALLER_PANE_ID"

for ((i=0; i<TOTAL_TASKS; i++)); do
  NAME="${TASK_NAMES[$i]}"
  BRANCH="${TASK_BRANCHES[$i]}"
  PROMPT="${TASK_PROMPTS[$i]}"
  
  echo ""
  echo "--> [$((i+1))/$TOTAL_TASKS] Setting up task: $NAME ($BRANCH)..."

  TARGET_DIR="$REPO_ROOT"
  if [[ "$WORKTREE_MODE" != "none" ]]; then
    SLUG="$(basename "$BRANCH" | tr '/' '-')"
    TARGET_DIR="$WORKTREE_ROOT/$SLUG"
    
    if [[ ! -d "$TARGET_DIR" ]]; then
      echo "    Creating worktree at $TARGET_DIR..."
      if [[ "$WORKTREE_MODE" == "herdr" ]]; then
        # Try native herdr worktree create first
        if ! herdr worktree create --cwd "$REPO_ROOT" --branch "$BRANCH" --base "$BASE_REF" --path "$TARGET_DIR" --no-focus >/dev/null 2>&1; then
          # Fallback to git worktree add
          git -C "$REPO_ROOT" worktree add -b "$BRANCH" "$TARGET_DIR" "$BASE_REF" >/dev/null 2>&1 || \
          git -C "$REPO_ROOT" worktree add "$TARGET_DIR" "$BRANCH" >/dev/null 2>&1
        fi
      else
        git -C "$REPO_ROOT" worktree add -b "$BRANCH" "$TARGET_DIR" "$BASE_REF" >/dev/null 2>&1 || \
        git -C "$REPO_ROOT" worktree add "$TARGET_DIR" "$BRANCH" >/dev/null 2>&1
      fi
    else
      echo "    Using existing worktree directory $TARGET_DIR"
    fi
  fi
  CREATED_DIRS+=("$TARGET_DIR")

  NEW_PANE_ID=""
  if [[ "$STYLE" == "tab" ]]; then
    echo "    Opening new tab in workspace $WORKSPACE_ID..."
    TAB_RES="$(herdr tab create --workspace "$WORKSPACE_ID" --cwd "$TARGET_DIR" --label "$NAME" --no-focus)"
    NEW_PANE_ID="$(echo "$TAB_RES" | jq -r '.result.root_pane.pane_id // .result.tab.root_pane_id // empty')"
    if [[ -z "$NEW_PANE_ID" ]]; then
      # Query pane list for the new tab
      TAB_ID="$(echo "$TAB_RES" | jq -r '.result.tab.tab_id')"
      NEW_PANE_ID="$(herdr pane list --workspace "$WORKSPACE_ID" | jq -r ".result.panes[] | select(.tab_id == \"$TAB_ID\") | .pane_id" | head -n 1)"
    fi
  else
    # Style == pane
    # Inspect geometry of target split pane
    LAYOUT="$(herdr pane layout --pane "$LAST_PANE_ID" 2>/dev/null || true)"
    DIRECTION="right"
    if [[ -n "$LAYOUT" ]]; then
      WIDTH="$(echo "$LAYOUT" | jq -r ".result.layout.panes[] | select(.pane_id == \"$LAST_PANE_ID\") | .rect.width // 100")"
      HEIGHT="$(echo "$LAYOUT" | jq -r ".result.layout.panes[] | select(.pane_id == \"$LAST_PANE_ID\") | .rect.height // 40")"
      # If wide, split right; if tall/narrow, split down
      if (( WIDTH < 140 && HEIGHT >= 30 )); then
        DIRECTION="down"
      fi
    fi

    echo "    Splitting pane from $LAST_PANE_ID (direction: $DIRECTION)..."
    SPLIT_RES="$(herdr pane split --pane "$LAST_PANE_ID" --direction "$DIRECTION" --cwd "$TARGET_DIR" --no-focus)"
    NEW_PANE_ID="$(echo "$SPLIT_RES" | jq -r '.result.pane.pane_id')"
    LAST_PANE_ID="$NEW_PANE_ID"
  fi

  echo "    Assigned Pane ID: $NEW_PANE_ID"
  CREATED_PANES+=("$NEW_PANE_ID")

  # Start the agent
  echo "    Starting $AGENT_KIND as agent '$NAME'..."
  START_CMD=(herdr agent start "$NAME" --kind "$AGENT_KIND" --pane "$NEW_PANE_ID")
  if [[ -n "$AGENT_ARGS" ]]; then
    START_CMD+=(-- $AGENT_ARGS)
  fi

  if ! "${START_CMD[@]}" >/dev/null 2>&1; then
    echo "    Warning: agent start command returned non-zero, waiting 3s for detection..." >&2
    sleep 3
  fi
  CREATED_AGENTS+=("$NAME")

  # Prompt the agent if prompt is not empty
  if [[ -n "$PROMPT" ]]; then
    echo "    Submitting prompt to '$NAME'..."
    herdr agent prompt "$NAME" "$PROMPT" --wait --until working --timeout 25000 >/dev/null 2>&1 || {
      echo "    Notice: agent prompt queued or waiting for activity."
    }
  fi
done

# Restore focus to caller pane
if [[ -n "$CALLER_PANE_ID" ]]; then
  herdr agent focus "$CALLER_PANE_ID" >/dev/null 2>&1 || true
fi

echo ""
echo "=== Swarm Launch Summary ==="
printf "%-18s | %-10s | %-24s | %-35s\n" "Agent Name" "Pane ID" "Branch" "Directory"
printf "%-18s-+-%-10s-+-%-24s-+-%-35s\n" "------------------" "----------" "------------------------" "-----------------------------------"
for ((i=0; i<TOTAL_TASKS; i++)); do
  printf "%-18s | %-10s | %-24s | %-35s\n" \
    "${CREATED_AGENTS[$i]}" \
    "${CREATED_PANES[$i]}" \
    "${TASK_BRANCHES[$i]}" \
    "${CREATED_DIRS[$i]}"
done
echo "============================"
echo "Monitor with: herdr agent list"
echo "Inspect with: herdr agent read <name> --lines 50"
