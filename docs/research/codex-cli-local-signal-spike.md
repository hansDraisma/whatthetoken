# Codex CLI Local Signal Spike

Date: 2026-05-04

## Goal

Determine whether WhatTheToken can observe useful Codex CLI consumption signals locally without collecting prompts, responses, cookies, bearer tokens, auth headers, or provider session tokens.

## Commands Run

- `which codex`
- `codex --version`
- `codex --help`
- `ls -la ~/.codex`
- `find ~/.codex -maxdepth 2 -type f \( ... \)`

## Findings

- Codex CLI is installed at `/opt/homebrew/bin/codex`.
- Version: `codex-cli 0.128.0`.
- Relevant visible commands include `exec`, `review`, `login`, `logout`, `resume`, `fork`, `cloud`, `debug`, and `features`.
- The top-level help does not expose a dedicated usage or quota command.
- Candidate local metadata files by path only:
  - `~/.codex/version.json`
  - `~/.codex/models_cache.json`
  - `~/.codex/config.toml`
  - `~/.codex/state_5.sqlite`
  - `~/.codex/logs_2.sqlite`
  - `~/.codex/sqlite/codex-dev.db`
  - `~/.codex/.codex-global-state.json`
- Sensitive or likely-sensitive paths by path only:
  - `~/.codex/auth.json`
  - `~/.codex/history.jsonl`
  - `~/.codex/sessions`
  - `~/.codex/shell_snapshots`

## Sensitive Data Review

No file contents were printed or copied. The directory listing shows files that likely contain credentials, prompts, responses, command history, or session state. Those files are not safe to parse without a separate redaction review and explicit user permission.

The SQLite files may contain useful aggregate state, but their table contents were not inspected because they may also include session or conversation data.

## Recommendation

Needs manual user permission and redaction review.

The next safe step is to inspect Codex-owned metadata schemas with a script that lists SQLite table names and JSON top-level keys only, with explicit deny rules for auth, history, sessions, shell snapshots, prompts, responses, and command output.
