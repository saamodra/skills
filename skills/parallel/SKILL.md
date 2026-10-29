---
name: parallel
description: Run the current work as parallel Orca workers, each in a new worktree, each ending in its own PR. Pass the worker model, e.g. `/parallel claude 5.5 sonnet medium`.
argument-hint: "<agent> <model> <effort> [tasks]  e.g. claude 5.5 sonnet medium"
---

You are the **coordinator**. Split the work into independent tasks, run each in its own Orca worker and worktree, and deliver one PR per task. You write no feature code yourself.

## 1. Parse the launch spec

Read the arguments as `<agent> <model> <effort>`, followed by optional task text.

- **agent**: an Orca agent id (`claude`, `codex`, `cursor`, …).
- **model**: for `claude`, turn `<version> <family>` into the provider id `claude-<family>-<major>-<minor>`: `5.5 sonnet` → `claude-sonnet-5-5`, `5.5 opus` → `claude-opus-5-5`, `5.1 fable` → `claude-fable-5-1`. Pass any other agent's model through verbatim.
- **effort**: one of `low`, `medium`, `high`, `xhigh`, `max`.

The tasks are the task text, or else the work already agreed in this conversation. When the agent, model, or tasks are missing, ask before launching anything.

## 2. Split into tasks

Each task is one PR-sized, independently mergeable change. Write every spec to the task-spec contract in the `orchestration` skill (Target, Change, Constraints, Ownership, Observable acceptance), self-contained enough for a cold worker.

Give each task a disjoint set of files. When two tasks must edit the same file, merge them or order them with a dependency so their PRs never conflict.

End every spec with this delivery clause:

> Follow the repo's AGENTS.md / CLAUDE.md, including its verification commands and commit rules. Commit on your worktree's branch with conventional-commit messages, push it, and open a PR against the default branch with `gh pr create`. Put the PR URL and the verification you ran in your `worker_done` summary.

Show the user the task list (one line each, with dependencies) and launch straight away.

## 3. Launch

Load the `orchestration` skill and run its version-matched guide, plus the `placement-and-remote` and `coordinator-loop` references. Create one Run, then start every ready task before the first wait:

```text
orca orchestration worker-start --task <task_id> --run <run_id> \
  --worktree new-top-level --name <task-slug> --base-branch <default-branch> --setup run \
  --agent <agent> --model <model-id> --effort <effort> --json
```

Compare `launch.effective` with what you requested. Report any mismatch to the user instead of silently accepting it.

## 4. Supervise

Run the orchestration guide's wait loop until every Dispatch settles: answer questions, start dependent tasks once their dependencies succeed, and follow its recovery rules for failures.

Accept a `worker_done` only after `gh pr view <url>` shows an open PR whose diff matches the task. Then release the worker.

## 5. Report

Done when every task has an outcome and no worker is left reclaimable. Give the user one row per task: outcome, PR URL, the verification the worker ran, and any blocker.
