# ADR 0001: Local-First Minimal-Data Ingestion

Date: 2026-05-04

## Status

Proposed

## Context

WhatTheToken needs usage signals from products that often do not expose public quota APIs. The user is already authenticated locally through CLI tools, desktop apps, IDEs, or browser sessions. Collecting credentials or provider session data centrally would create unacceptable trust and security risk.

## Decision

Usage ingestion happens locally whenever possible. Local ingestors send only sanitized usage events and derived snapshots to the backend.

The backend must not receive prompts, completions, conversation contents, cookies, auth headers, bearer tokens, or provider session tokens.

## Alternatives Considered

- Server-side provider login: rejected because it requires handling user credentials or session cookies.
- Browser cookie extraction from desktop: rejected because it requires intrusive permissions and resembles malware behavior.
- Provider-private endpoints from backend: rejected because authentication and stability are unacceptable for v1.
- Local-only product with no backend: rejected for now because cross-device sync, history, and eventual billing are part of the product.

## Consequences

- The product has a stronger trust posture.
- Some numbers will be incomplete when activity happens on untracked devices.
- The UI must clearly show confidence, freshness, and undercount risk.
- Ingestor reliability becomes a core product responsibility.

