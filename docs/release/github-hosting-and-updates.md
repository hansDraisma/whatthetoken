# GitHub Hosting And Updates

WhatTheToken uses two repositories with a single customer destination:

- private source repository: implementation, tests, and signing/release scripts
- public distribution repository: `hansDraisma/whatthetoken-releases`

Customers use only the public distribution repository. It contains the download page, signed DMGs, checksums, privacy and security notices, support issues, and the Sparkle appcast. Source code, signing credentials, provider fixtures, internal diagnostics, and release-machine state remain private.

Public endpoints:

- customer page: `https://hansdraisma.github.io/whatthetoken-releases/`
- releases: `https://github.com/hansDraisma/whatthetoken-releases/releases`
- support: `https://github.com/hansDraisma/whatthetoken-releases/issues`
- appcast: `https://hansdraisma.github.io/whatthetoken-releases/appcast.xml`

This makes the customer experience one project without exposing private source or release secrets. GitHub Pages and GitHub Releases are available from the same public repository.

## Release Asset URLs

Use immutable, versioned public release assets:

```text
https://github.com/hansDraisma/whatthetoken-releases/releases/download/v0.1.0/WhatTheToken-0.1.0.dmg
https://github.com/hansDraisma/whatthetoken-releases/releases/download/v0.1.0/WhatTheToken-0.1.0.dmg.sha256
```

The appcast must point at the versioned DMG URL, never a mutable `latest` URL.

## Repository And Pages Setup

The public distribution repository must have:

1. Public visibility and Issues enabled.
2. Private vulnerability reporting enabled.
3. Immutable releases enabled before the first release.
4. Wiki and Projects disabled unless there is a maintained need.
5. GitHub Pages deployed from `main` at repository root.
6. Root `.nojekyll`, `index.html`, `appcast.xml`, privacy, security, license, and notices.
7. Issue forms that tell customers not to submit credentials, provider payloads, prompts, responses, cookies, auth headers, or raw diagnostics.

Verify before every release:

```bash
gh repo view hansDraisma/whatthetoken-releases --json visibility,hasIssuesEnabled
gh api repos/hansDraisma/whatthetoken-releases/immutable-releases --jq .enabled
curl -fL https://hansdraisma.github.io/whatthetoken-releases/
curl -fL https://hansdraisma.github.io/whatthetoken-releases/appcast.xml
```

Do not ship or announce a signed build with `SUFeedURL` until the appcast probe succeeds. A placeholder appcast is acceptable before the first release; the release appcast must contain a Sparkle EdDSA signature and point only at a published, verified DMG.

## Publication Boundary

Run `apps/mac/Scripts/publish-release.sh` locally from a clean, up-to-date private `main` checkout. The script requires a verified signed/notarized artifact and a signed source tag already pushed to the private source repository. It then:

1. verifies source provenance and release artifacts again,
2. creates a draft in the public distribution repository,
3. generates and validates the signed appcast locally,
4. publishes the immutable GitHub Release,
5. updates the public repository's root `appcast.xml`, and
6. downloads the public DMG and checksum to verify them.

Apple Developer ID, notarization, Sparkle private-key, and monitoring credentials remain on the release machine. The public repository receives only the DMG, checksum, signed appcast, customer documentation, and sanitized release notes. Public release publication is deliberately local and maintainer-approved; it is not an unattended workflow.

If publication is interrupted after the draft is created or the release is published, rerun the same command with `--resume`. Resume mode uploads only an asset missing from a still-mutable draft, downloads all hosted assets, compares them byte-for-byte with the locally verified DMG and checksum, and then safely completes release/appcast publication. It never replaces an existing release asset.

## Public V1 Update Posture

Public V1 is manual-first:

- GitHub Releases remain the fallback install/update path.
- Sparkle automatic background checks stay disabled with `SUEnableAutomaticChecks = false`.
- Silent installs stay disabled with `SUAutomaticallyUpdate = false`.
- The in-app `Check for Updates` action is manual-only.

Do not announce Sparkle update support until the signed old-build to new-build smoke passes.

## Long-Term Site Roadmap

An owned site or custom domain is optional after Public V1 is stable. Moving the appcast requires a redirect and migration plan for already-installed apps, an ownership and DNS recovery plan, and an update smoke. Do not change the appcast URL casually after public builds have shipped.
