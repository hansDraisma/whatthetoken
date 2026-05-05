# Security

## Supported Versions

Before Public V1, only the current private development branch is supported. Public V1 support begins after the first signed and notarized free DMG is published.

## Reporting A Vulnerability

Before Public V1, report vulnerabilities through an existing private maintainer channel. After the repository becomes public, use GitHub private vulnerability reporting if it is enabled.

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

## Out Of Scope

Reports that require collecting forbidden sensitive data are out of scope until a privacy-preserving reproduction exists. Unsupported forks and modified builds are outside the official support boundary.
