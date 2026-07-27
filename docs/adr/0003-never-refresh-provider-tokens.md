# ADR 0003: Never Refresh Provider Tokens

Date: 2026-07-27

## Status

Proposed

## Context

WhatTheToken can detect when a local provider credential is no longer usable and can observe when the provider-owned client replaces it. The Claude Code Keychain record also contains refresh-token material, which could appear to offer a direct recovery path.

OAuth refresh-token rotation for public clients is commonly single-use. If WhatTheToken redeemed Claude Code's refresh token, Claude Code could retain an invalidated copy and sign the user out. Updating the provider-owned Keychain record afterward would still risk changing its access controls, overwriting a newer credential in a lost-update race, and contradicting the product promise that WhatTheToken only reads provider credentials locally.

## Decision

WhatTheToken must never redeem refresh tokens, mint provider credentials, or write provider credentials.

Automatic recovery uses read-only local observation:

- read the provider-owned credential only after connector consent
- derive an access-token digest only in memory for change detection
- never persist the access token, refresh token, or token-derived digest
- let the provider-owned client perform authentication and rotation
- verify usage through the normal connector only after startup verification or a locally observed credential change

## Alternatives Considered

- Redeem the provider refresh token without writing it back: rejected because single-use rotation can invalidate the provider client's copy and sign the user out.
- Redeem the token and update the provider-owned Keychain item: rejected because it can damage Keychain access controls, lose races with the provider client, and makes WhatTheToken a credential owner.
- Persist a token fingerprint across launches: rejected because it is an identifier derived from provider credential material and is unnecessary for recovery.
- Require manual retries only: rejected because read-only local rotation detection can recover safely without taking ownership of authentication.

## Consequences

- Provider authentication remains owned by the provider's client.
- WhatTheToken can recover automatically after Claude Code rotates its credential, but it cannot repair a provider login itself.
- A token digest may exist only in process memory for the lifetime of an active watch.
- Startup verification and rotation-triggered verification may make provider usage requests for connectors the user has already enabled and not paused.
- Tests must use synthetic credentials and injected probes; they must not read the live Keychain or call provider services.
