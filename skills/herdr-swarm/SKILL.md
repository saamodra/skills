---
name: herdr-swarm
description: "Spawn and coordinate multiple AI coding agents in parallel across Herdr panes or tabs with isolated Git worktrees. Use when the user asks to run multiple tasks, issues, or PRs in parallel using Herdr, spawn agents across panes or tabs, or coordinate a multi-agent swarm."
---

# Herdr Swarm: Parallel Multi-Agent Orchestration

This skill teaches agents how to safely spawn and coordinate multiple AI coding agents running in parallel inside **Herdr**, with isolated Git worktrees and customizable terminal topology (panes in the current tab or new tabs in the workspace).

---

## 1. Prerequisites & Environment Check

Before executing any Herdr swarm operations, verify that the current session is running inside a Herdr-managed pane:

```bash
test "${HERDR_ENV:-}" = 1
```

If this check fails, notify the user that Herdr is not active and stop.

Read the injected caller environment:
```bash
printf 'Workspace: %s | Tab: %s | Pane: %s\n' "$HERDR_WORKSPACE_ID" "$HERDR_TAB_ID" "$HERDR_PANE_ID"
```

---

## 2. Core Orchestration Parameters

When a multi-task parallel request arrives, identify or ask for the following inputs:

| Parameter | Options / Format | Default |
| :--- | :--- | :--- |
| **Style** | `pane` (split current tab) or `tab` (new tabs) | `pane` |
| **Tasks** | List of issues (GitHub URLs/numbers), branch names, and task prompts | *Required* |
| **Agent Kind** | `agy`, `codex`, `claude`, `pi`, `cursor`, `gemini`, `devin`, etc. | `agy` |
| **Agent Args** | Native flags passed after `--` | `--dangerously-skip-permissions` |
| **Worktree Mode** | `herdr` (native), `git`, or `none` (shared cwd) | `herdr` |
| **Base Ref** | Target branch or commit | `main` (or current branch) |

---

## 3. Fast-Path: Using the Companion Script

The skill includes a production-tested companion script:
`~/.gemini/config/skills/herdr-swarm/scripts/herdr-swarm.sh`

### Command Line Usage

```bash
# Example: Spawn two tasks in split panes in the current tab
~/.gemini/config/skills/herdr-swarm/scripts/herdr-swarm.sh \
  --style pane \
  --base main \
  --task "feat-auth|feature/oauth2|Implement Google OAuth2 flow with unit tests" \
  --task "fix-cache|bugfix/cache-ttl|Fix cache expiration race condition and verify"
```

### JSON Input / Pipe Usage

```bash
cat << 'EOF' | ~/.gemini/config/skills/herdr-swarm/scripts/herdr-swarm.sh --style tab --tasks-json -
[
  {
    "name": "a5-create",
    "branch": "offline-sync/a5-durable-create",
    "prompt": "Implement durable offline record create per Issue #31 and run unit tests."
  },
  {
    "name": "r3-verify",
    "branch": "offline-sync/r3-create-pilot",
    "prompt": "Automate offline-create pilot verification per Issue #32 and prepare evidence."
  }
]
EOF
```

---

## 4. Manual / Step-by-Step Execution Protocol

When invoking Herdr commands directly without the helper script, strictly adhere to the following protocol:

### Step 1: Worktree Setup
Isolate each task in its own Git worktree to avoid file lock and index conflicts between concurrent agents.

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
WT_DIR="$HOME/orca/workspaces/$(basename "$REPO_ROOT")/<task-slug>"

# Option A: Native Herdr worktree
herdr worktree create --cwd "$REPO_ROOT" --branch "<branch-name>" --base "<base-ref>" --path "$WT_DIR" --no-focus

# Option B: Fallback Git worktree
git -C "$REPO_ROOT" worktree add -b "<branch-name>" "$WT_DIR" "<base-ref>"
```

### Step 2: Topology Creation (`pane` vs `tab`)

#### Style A: `pane` (Split in Current Tab)
Inspect caller pane dimensions to avoid creating unusably narrow columns:
```bash
herdr pane layout --pane "$HERDR_PANE_ID"
```
- If width >= 140 columns: split `right`
- If narrow or tall (width < 140 and height >= 30): split `down`

Always use `--no-focus` and specify the worktree path as `--cwd`:
```bash
SPLIT_JSON="$(herdr pane split --pane "$TARGET_PANE_ID" --direction right --cwd "$WT_DIR" --no-focus)"
NEW_PANE_ID="$(echo "$SPLIT_JSON" | jq -r '.result.pane.pane_id')"
```

#### Style B: `tab` (New Tab in Workspace)
```bash
TAB_JSON="$(herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$WT_DIR" --label "<task-name>" --no-focus)"
NEW_PANE_ID="$(echo "$TAB_JSON" | jq -r '.result.root_pane.pane_id')"
```

### Step 3: Start the Agent
Agent names must be lowercase alphanumeric with hyphens/underscores (`[a-z][a-z0-9_-]{0,31}`) and unique among live agents:
```bash
herdr agent start <unique-agent-name> --kind agy --pane "$NEW_PANE_ID" -- --dangerously-skip-permissions
```
Wait up to 30 seconds for Herdr to report `interactive_ready: true`.

### Step 4: Submit Prompt & Verify Handoff
Submit the task prompt and wait for the agent to enter `working` state:
```bash
herdr agent prompt <unique-agent-name> "<detailed-task-prompt>" --wait --until working --timeout 25000
```

### Step 5: Restore Caller Focus & Present Dashboard
Ensure the orchestrating pane remains focused:
```bash
herdr agent focus "$HERDR_PANE_ID"
```

Render an execution table for the user:
```markdown
| Task | Pane ID | Agent Name | Worktree Path | Branch | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Task 1 | `w1:p2` | `agent-task-1` | `/path/to/wt1` | `feat/task-1` | Working |
| Task 2 | `w1:p3` | `agent-task-2` | `/path/to/wt2` | `feat/task-2` | Working |
```

Provide quick commands for user monitoring:
- `herdr agent list`
- `herdr agent read <agent-name> --lines 50`
- `herdr agent wait <agent-name> --until idle done`

---

## 5. Safety & Etiquette Rules

1. **Focus Preservation**: Always pass `--no-focus` when creating tabs or splitting panes so the user's focus is never stolen. Re-focus the caller pane after launching.
2. **Worktree Isolation**: Never point two concurrent agents at the exact same working directory when they both make file edits or run builds.
3. **Graceful Failure**: If an agent reports `agent_not_ready` or stalls during prompt submission, inspect `herdr agent get <name>` and `herdr pane read <pane-id>` before retrying.
4. **Clean Exit**: When an agent completes its turn and returns to shell, Herdr marks it `idle` or `done`. Do not kill panes unless explicitly requested by the user.
