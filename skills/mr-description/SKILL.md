---
name: mr-description
description: Use when creating a merge/pull request description from staged changes, last commit, or conversation context. Do not use for existing PRs needing description updates.
---

# MR Description

Generate MR description as new markdown file. Do not commit file unless user explicitly asks.

## Input

Pick from (priority order):
1. `git diff --cached` (staged changes) — if user mentions staged
2. `git diff HEAD~1` (last commit) — if user mentions commit
3. Current conversation context + `git diff origin/master..HEAD` — default

## Output

New markdown file named `<branch-name>-mr.md` (e.g. `super-b-fix-cookie-json-parse-mr.md`).

## Storage Path

Check project root for `_llm/` directory:
- Exists → save as `<project-root>/_llm/<branch-name>-mr.md`
- No `_llm/` → save as `<project-root>/<branch-name>-mr.md`

## Content Rules

| Type | Section | Content |
|------|---------|---------|
| Bug | `## Problem` | What was broken, root cause, impact |
| Bug | `## Fix` | What changed, how it resolves problem |
| Feature/Chore | `## Motivation` | Why this change exists, context |
| Feature/Chore | `## Goals` | What this achieves, success criteria |

**Never include:**
- `## Test` or `## Testing` section
- `## Changes` or file list / diff stat
- `## Checklist`
- Implementation details not relevant to the description
- Any section not listed above

**Keep descriptions meaningful.** One paragraph per section. No fluff.
