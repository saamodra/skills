---
name: production-debug-human-loop
description: Use when debugging production issues where direct database, service, or data access is unavailable and information must be gathered by asking the user to run commands, scripts, or queries and report results back.
---

# Production Debug Human-in-the-Loop

## Overview

User reports production issue. You cannot access servers, DB, logs, or any data directly. You guide user to run specific commands/scripts/queries, analyze returned output, then narrow down until root cause found.

## Flow

1. **Analyze from code** — Reason from error messages, stack traces, code paths, recent changes. Can you determine root cause without production data? If yes, answer directly. Stop.
2. **Need data? Ask precisely** — Tell user *exactly* what to run (Rails console snippet, SQL query, curl, script). Explain what to look for in output.
3. **User reports back** — Read output. Analyze. Narrow or pivot.
4. **Iterate** — Repeat steps 2-3 until root cause found.

## Command Templates

### Rails Production Console
```
# In rails console production:
User.find_by(email: "xxx")
ProductCatalog.find(id).subscriptions.active.count
Rails.cache.read("cache_key")
Sidekiq::Queue.new("default").size
```

### SQL
```sql
SELECT column, count(*) FROM table
WHERE condition
GROUP BY column ORDER BY count DESC;
```

### Log grep suggestion
```
# Suggest exact log file path and grep pattern:
grep "ERROR\|Timeout" /var/log/app/production.log | tail -50
```

### VictoriaLogs / LogsQL

Vidio has 2 VictoriaLogs clusters.

| Environment | URL |
|---|---|
| Staging | `http://vmauth.staging.kmklabs.com` |
| Production | `http://vmauth.prod.kmklabs.com` |

Only give the **LogsQL query string** (not curl). User pastes into VictoriaLogs web UI search bar. **Do NOT include `_time:`** — user picks time in UI.

**Base pattern** (no pipes unless needed):
```
{stream_filter} word1 AND word2 AND "phrase with spaces"
```

Stream filters for Vidio infra:
- **vidioweb (VM)**: `{component="vidioweb"}` with `type:rubyapp` or `type:nginxaccess`
- **K8s services**: `{kubernetes.pod_namespace="vidio-quiz"}`

**Vidio Rails log format** — each request writes these lines sequentially:
```
Started POST "/api/login" for IP...
Processing by Api::SessionsController#create as JSON
  Parameters: {"login" => "user@email.com", ...}
X-Secure-Level: ...
X-Trace-Id: ...
x-datadog-trace-id: ...
X-Country-Alpha2: ID
Platform: app-ios
[API] IP = ... ; Path = ... ; Params = {...} ; Message = Email not found.
Completed 401 Unauthorized in 13ms (Views: ...)
```

Key patterns to search:
- **Platform**: `Platform: app-ios` (separate line from the request — correlates with surrounding lines)
- **Error message**: `[API]` lines contain `Message = <text>`
- **Params**: `Parameters: {"login" => "..."}`
- **Endpoint**: `Started POST "/api/login"`
- **Status**: `Completed 200 OK`, `Completed 401 Unauthorized`, etc.

Queries use simple `AND`/`OR` — no `|` pipes. User adjusts time in UI.

Examples:
```
{component="vidioweb"} type:rubyapp AND "Platform: app-ios" AND "/api/login"

{component="vidioweb"} type:rubyapp AND "[API]" AND "/api/login" AND "Email not found"

{component="vidioweb"} type:rubyapp AND "Platform: app-android" AND "/api/login"

{component="vidioweb"} type:rubyapp AND "Completed 500" AND "/api/login"

{component="vidioweb"} type:rubyapp AND "[API]" AND "/partner" AND "timeout"
```

Always explain what to look for in results. For Rails API errors, look at `Message =` in `[API]` lines to see the error reason, and `Completed <status>` to confirm HTTP response.

## Guiding Principles

- **Exact commands** — Never say "check the logs" or "look at the data." Say `grep 'Timeout' /var/log/app/production.log | tail -20`.
- **Minimal ask** — One small query at a time. Each answer narrows the search space.
- **Explain what** — Tell user what the output means before they run it, so they can sanity-check.
- **Code-first** — Always exhaust what code analysis can tell you before asking for production data. Many bugs are obvious from code alone.
- **Assume user = developer** — User can run rails console, SQL, curl, grep. Give raw commands, not clicks.

## Anti-Patterns

| Bad | Good |
|---|---|
| "Check if the user exists" | `User.find_by(email: "user@example.com")` — if nil, user never created |
| "Look at the logs" | `grep 'transaction_id=abc123' /var/log/app/production.log` |
| Dump everything at once | One focused query. Wait for answer. |
| Ask without context | "Run X. Expected output: Y. If you see Z instead, that means..." |
| **Edit code during debug** | **ZERO code modification. Analyze only. Report root cause + suggested fix. Let user decide.** |

## When NOT to Use

- Issue reproducible in dev/staging — debug there directly
- Question answerable from code review alone
- Need real-time monitoring dashboards you should look at yourself
