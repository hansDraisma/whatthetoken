# Security

## Supported Versions

The latest signed and notarized release in `hansDraisma/whatthetoken-releases` is supported. Private development builds and older prerelease candidates are unsupported.

## Reporting A Vulnerability

Use private vulnerability reporting in `hansDraisma/whatthetoken-releases`. If it is unavailable, use the monitored fallback address `draisma.hans@gmail.com`. Do not submit vulnerabilities as public issues.

Do not paste secrets, provider tokens, cookies, auth headers, prompts, responses, raw provider payloads, raw local database rows, or sensitive local paths into issues, discussions, pull requests, or logs.

## Useful Report Content

Include only sanitized details:

- WhatTheToken version or commit
- macOS version
- connector name
- sanitized connector state
- reproduction steps
- expected behavior
- actual behavior
- whether the issue reproduces with synthetic fixtures

## Local Security Model

Provider credentials stay local. Connectors may use local provider credentials or app-server state in memory only after explicit user consent. WhatTheToken stores sanitized usage status, connector settings, and preferences, not copied provider credentials.

## Official Builds

Official builds are only the signed and notarized DMGs published at `https://github.com/hansDraisma/whatthetoken-releases/releases`. Release checksums are published beside the DMG.

Developer ID signing, notarization credentials, and Sparkle EdDSA private material must stay outside the repository. Sparkle appcast publishing is part of the release checklist and must not point to unpublished or unverified artifacts.

Unsupported forks, local builds, modified DMGs, and re-signed apps are outside the official build trust boundary.

## Out Of Scope

Reports that require collecting forbidden sensitive data are out of scope until a privacy-preserving reproduction exists. Unsupported forks and modified builds are outside the official support boundary.
