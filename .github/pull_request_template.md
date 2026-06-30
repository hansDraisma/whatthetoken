## Summary

<!-- What does this change do, and why? -->

## Review checklist

Per `CONTRIBUTING.md`. Confirm before requesting review:

- [ ] Privacy deny-list is not weakened (no real provider tokens, payloads, prompts, cookies, auth headers, DB rows, browser state, or sensitive local paths)
- [ ] Fixtures/tests use **synthetic** data only
- [ ] Provider credentials are used in memory only and never persisted; raw provider responses are discarded after parsing and never logged/persisted
- [ ] Every displayed number has a confidence label; stale state remains visible
- [ ] Sanitized source states are emitted instead of raw provider errors (parser/source version metadata added where relevant)
- [ ] `pnpm --filter @whatthetoken/core test` passes
- [ ] `swift test` passes from `apps/mac`
- [ ] Docs updated if privacy boundaries, schema shape, confidence semantics, or connector source boundaries changed (`docs/architecture/*` or an ADR)

## Notes

<!-- Screenshots, follow-ups, or anything reviewers should know. -->
