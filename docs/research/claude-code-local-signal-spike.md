# Claude Code Local Signal Spike

Date: 2026-05-04

## Goal

Determine whether WhatTheToken can observe useful Claude Code subscription or usage signals locally without collecting prompts, responses, cookies, bearer tokens, auth headers, provider session tokens, or Keychain secret values.

## Commands Run

- `which claude`
- `claude --version`
- `claude --help`
- `security find-generic-password -s "Claude Code-credentials"`
- `ls -la ~/.claude`
- `find ~/.claude -maxdepth 2 -type f \( ... \)`

## Findings

- Claude Code is installed at `/Users/hansdraisma/.local/bin/claude`.
- Version: `2.1.126 (Claude Code)`.
- Relevant visible commands/options include `auth`, `doctor`, `setup-token`, `--max-budget-usd`, `--model`, `--output-format`, and `--print`.
- The top-level help does not expose a dedicated usage or quota status command.
- The Keychain item `Claude Code-credentials` exists for account `hansdraisma`. Only Keychain metadata was printed; secret values were not requested.
- Candidate local metadata files by path only:
  - `~/.claude/policy-limits.json`
  - `~/.claude/settings.json`
  - `~/.claude/settings.local.json`
  - `~/.claude/remote-settings.json`
  - `~/.claude/mcp-needs-auth-cache.json`
- Sensitive or likely-sensitive paths by path only:
  - `~/.claude/history.jsonl`
  - `~/.claude/sessions`
  - `~/.claude/projects`
  - `~/.claude/paste-cache`
  - `~/.claude/shell-snapshots`
  - `~/.claude/session-env`
  - `~/.claude/todos`

## Sensitive Data Review

No file contents were printed or copied. The Keychain command omitted `-g`, so no secret material was printed. Several local Claude paths likely contain prompts, responses, project context, shell output, environment snapshots, or session state and should be excluded from automated parsing unless a future redaction review proves otherwise.

`~/.claude/policy-limits.json` is the most promising filename for a safe local quota signal, but its contents were not inspected during this spike.

## Recommendation

Needs manual user permission and redaction review.

The next safe step is a narrow metadata inspection that reads only top-level keys from `~/.claude/policy-limits.json` and any documented Claude Code status output, while explicitly avoiding Keychain secret values, history, sessions, projects, paste cache, shell snapshots, and session environment files.

## Implementation Follow-Up

The Claude Code local connector plan is documented in `docs/superpowers/plans/2026-05-04-local-connector-trust.md`.

Implementation must keep the Claude Code OAuth token local to the Mac connector process. Tests use synthetic credentials and fixture responses only. Synced and displayed data is limited to sanitized `UsageSnapshot` records with connector source metadata.

The first implementation maps Claude Code utilization windows (`five_hour`, `seven_day`, `seven_day_opus`, `seven_day_sonnet`) and enabled `extra_usage` credits into sanitized snapshots. Credential access is isolated behind a local command runner with a timeout so Keychain lookup failures do not block refresh indefinitely.

Manual smoke verification is available through the Mac app executable:

```bash
cd apps/mac
CLAUDE_CODE_VERSION="$(claude --version | awk '{print $1}')" swift run WhatTheTokenMac --claude-connector-smoke
```

The smoke path is developer-only and local-only. It requires `CLAUDE_CODE_VERSION` before credential access or networking and prints only sanitized connector status plus snapshot summaries. It must not be added to CI because CI must not depend on real Keychain credentials or live Anthropic responses.

The first local smoke run was completed on 2026-05-04 with Claude Code `2.1.126`. It returned sanitized summaries for `five_hour`, `seven_day`, `seven_day_sonnet`, and `monthly_extra_usage`. The output did not print the OAuth token, authorization header, raw provider JSON, prompts, responses, session data, or local file contents.

The product wiring now exposes Claude Code through an explicit Mac app opt-in path. The app starts disconnected, shows `Connect Claude Code`, and does not read the Claude Code Keychain item, run `claude --version`, or call Anthropic until the user chooses to connect. Successful refresh results render only sanitized snapshots through the existing status cards; unavailable states render structured connector status copy.

The product path resolves the Claude executable from `PATH` plus common local install paths so Finder-launched app sessions can still detect locally installed Claude Code. While a refresh is checking, additional connect attempts are ignored to avoid overlapping provider requests and stale completion races.

The opt-in UI copy is covered by Swift tests for every connector setup state. A bounded local GUI smoke was run with `swift run WhatTheTokenMac`; the process launched and stayed alive for five seconds before being terminated cleanly, which verifies startup/render does not immediately crash or trigger the smoke command path.

Codex remains deferred to the roadmap until its local metadata and redaction review identifies a safe signal source.
