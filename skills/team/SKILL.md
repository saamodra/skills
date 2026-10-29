---
name: team
description: Split a task across a model-routed team in this worktree. Sonnet builders and critic, an Opus advisor, this session as lead.
argument-hint: "<task>"
disable-model-invocation: true
model: claude-opus-5-5
effort: high
---

# Team

You are the **lead** of a team working on: $ARGUMENTS

## Roster

| Name | Agent type | Model, effort | Job |
| --- | --- | --- | --- |
| `builder-<slice>` | `team-builder` | Sonnet 5.5, medium | Implements one slice inside the files it owns |
| `critic` | `team-critic` | Sonnet 5.5, medium | Devil's advocate: attacks the plan and the diffs, edits nothing |
| `advisor` | `team-advisor` | Opus 5.5, high | Consulted at decision points, edits nothing |
| `scout-<area>` | `team-scout` | Haiku 5.5, low | Read-only legwork for one area: files, usages, test output |

Each agent definition carries its model and effort. Spawn with `subagent_type` and `name` only, and leave the Agent tool's `model` and `effort` empty so the definition decides. The `name` lets agents message each other with SendMessage.

With `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, the named agents form an agent team with a shared task list. Without it they run as named background subagents. The steps are the same in both modes.

## Steps

1. **Scope.** Read the project's `CLAUDE.md`, the docs it points to for the areas involved, and the code the task touches. When that code spans more than you can read quickly, spawn one `scout-<area>` per area, all in one message, each with the question to answer: which files the task touches, who calls them, what the tests cover. Wait for their reports, then shut the scouts down. Cut the work into slices, each owning an explicit set of files or folders. Done when every file the task will change belongs to exactly one slice. Two slices that need the same file become one slice. If the result is a single slice, tell the user a team adds cost without parallelism here, and do the work yourself.

2. **Advise.** Spawn `advisor` with the task, the slices, their file ownership, the project's verification commands, and your proposed approach. Done when its reply is in and you have adopted or rejected each point, with a reason for each rejection.

3. **Spawn.** Spawn one `builder-<slice>` per slice, all in one message. Add `critic` when the change is risky or design-heavy. Leave it out for mechanical work. If TaskCreate is available, create one task per slice, assigned to its builder. Each builder prompt carries:
   - the goal and the slice;
   - the files it owns, with everything else read-only;
   - the verification command for its folder, from the project's docs;
   - the advisor guidance that applies to the slice;
   - the report format: files changed, what each change does, the exact verification result, and anything unverified.

   Send `critic` the plan and the slices, and tell it to review each builder's diff once that builder reports.

4. **Wait.** Builders and the critic report back on their own. Keep your hands off their files while they work. Answer questions they send you. Done when every builder has reported.

5. **Review.** For each slice, read the diff yourself and check it against the project's rules and the critic's findings. Send real defects back to the slice's builder, or fix small ones yourself. Done when every diff is read and every finding is fixed or dismissed with a stated reason.

6. **Verify.** Run each touched folder's build and tests yourself, on the combined working tree. Done when every command passes, or each failure is reported with its output.

7. **Report.** Tell the user what each slice changed, the verification results, anything unverified, and what is still open. Ask the remaining agents to shut down. Commit only when the user asks.
