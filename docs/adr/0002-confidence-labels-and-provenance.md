# ADR 0002: Confidence Labels And Provenance

Date: 2026-05-04

## Status

Proposed

## Context

Some providers expose authoritative usage data, while others require observation and estimation. Showing all numbers as equally reliable would mislead users and damage trust.

## Decision

Every usage event and snapshot must carry a confidence label:

- `verified`: authoritative provider or local quota data
- `observed`: directly counted local action
- `estimated`: inferred from observed activity and public limits
- `stale`: last signal is too old to trust

The UI must show confidence and freshness near the usage number.

## Alternatives Considered

- Hide confidence details in documentation: rejected because users need to understand reliability at decision time.
- Use only estimated counters for all providers: rejected because it discards higher-quality data from providers like Anthropic when available.
- Use provider-specific labels: rejected because it creates inconsistent UI and data handling.

## Consequences

- The product can mix verified and estimated providers without pretending they are equivalent.
- Tests must cover confidence propagation.
- Product copy must be direct about undercount and stale states.

