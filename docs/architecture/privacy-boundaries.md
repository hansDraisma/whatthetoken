# Privacy Boundaries

WhatTheToken must never collect:

- prompts
- completions
- conversation content
- conversation URLs
- cookies
- auth headers
- bearer tokens
- provider session tokens
- browser request bodies

Allowed usage data:

- provider
- product
- surface
- model key when detectable
- event type
- count, utilization, request, token, or credit amount
- observed timestamp
- device identifier
- confidence level
- source/parser version
- sync/error status

## Local Connector Trust Boundary

The Mac connector exists to keep provider credentials on the user's device.

For Claude Code, the connector may read the local Claude Code Keychain item with explicit user consent and use the OAuth access token in memory to request usage status from Anthropic. The token must not be uploaded, synced, logged, copied into fixtures, exposed to the Chrome extension, or stored by WhatTheToken.

The current Mac implementation isolates Keychain access behind a local command runner. The runner invokes `/usr/bin/security find-generic-password -s "Claude Code-credentials" -w`, bounds the lookup with a timeout, and returns either command output or a local connector error. The credential parser extracts only `claudeAiOauth.accessToken`; all persisted and synced output remains limited to sanitized snapshot data.

The product benefit is not "we never touch credentials anywhere." The accurate claim is:

> Provider credentials stay local. WhatTheToken syncs only sanitized usage status.

This lets users get higher-confidence Claude Code and Codex status without pasting provider tokens into a website, granting backend access to provider accounts, or creating separate Anthropic Admin/API credentials just to see subscription usage.

## V1 Security Baseline

Ship these controls from the start:

- explicit opt-in before reading local provider state
- no backend storage of provider credentials
- no Chrome extension access to local Keychain values
- no local or remote logging of tokens, prompts, responses, or session contents
- bounded local credential lookup so connector refresh cannot hang indefinitely
- fixture-based tests only, with synthetic usage data
- confidence, freshness, and source labels on every status value

## Future Privacy Hardening

After the first useful local connector works, evaluate a dedicated hardening phase:

- signed and notarized Mac connector distribution
- hardened runtime and sandbox review
- signed auto-updates
- local encrypted cache for connector state
- redacted diagnostic export that users can inspect before sharing
- optional end-to-end encryption for synced snapshots if product research shows users consider usage metadata sensitive enough to justify the added complexity
- independent security review before paid beta or broader launch

Do not add these as invisible scope creep to Phase 1. Keep the V1 privacy baseline strict, then make advanced hardening a deliberate product milestone.

Any future change to these boundaries requires an ADR.
