# GitHub Hosting And Updates

Public V1 uses GitHub-hosted infrastructure:

- DMG artifact: GitHub Releases
- checksum artifact: GitHub Releases
- Sparkle appcast: GitHub Pages from the repository `/docs` folder
- stable appcast URL: `https://hansdraisma.github.io/whatthetoken/appcast.xml`

This is the simplest correct hosting model for the first public release. It avoids running an update server while still giving installed apps a stable HTTPS appcast URL.

## Release Asset URLs

Use versioned GitHub Release assets:

```text
https://github.com/hansDraisma/whatthetoken/releases/download/v0.1.0/WhatTheToken-0.1.0.dmg
https://github.com/hansDraisma/whatthetoken/releases/download/v0.1.0/WhatTheToken-0.1.0.dmg.sha256
```

The appcast should point at the versioned DMG URL, not at a mutable `latest` URL.

## GitHub Pages Setup

In repository settings:

1. Enable GitHub Pages.
2. Source: deploy from branch.
3. Branch: `main`.
4. Folder: `/docs`.
5. Confirm `docs/.nojekyll` is committed.

After GitHub Pages publishes, verify:

```bash
curl -fL https://hansdraisma.github.io/whatthetoken/appcast.xml
```

Do not embed `SUFeedURL` in a public build until this URL is stable and the Sparkle public key is embedded.
Do not ship or announce a signed build with `SUFeedURL` until this curl probe returns a published appcast. A placeholder appcast is acceptable before the first release; the signed release appcast must point only at published GitHub Release assets.

## Public V1 Update Posture

Public V1 is manual-first:

- GitHub Releases remain the fallback install/update path.
- Sparkle automatic background checks stay disabled with `SUEnableAutomaticChecks = false`.
- Silent installs stay disabled with `SUAutomaticallyUpdate = false`.
- The in-app `Check for Updates` action may be visible in builds that embed `SUFeedURL` and `SUPublicEDKey`; it must remain manual-only.

The repo can prepare the action and scripts, but the maintainer must complete key custody, signed release publication, appcast generation, and update smoke before treating Sparkle as live. Do not announce Sparkle update support until the signed old-build to new-build smoke passes.

## Long-Term Site Roadmap

An owned site or custom domain is a Stage 5D item after Public V1 is stable. Moving away from GitHub Pages requires:

- redirect design for already-installed apps using the original `SUFeedURL`,
- appcast migration test,
- analytics-free download page decision,
- ownership and DNS recovery plan,
- updated release checklist.

Do not change the appcast URL casually after public builds have shipped.
