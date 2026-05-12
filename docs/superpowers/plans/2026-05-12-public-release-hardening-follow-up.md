# Public Release Hardening Follow-Up Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the remaining Public V1 signed-release readiness gaps without moving Apple signing, notarization, or Sparkle private keys into CI.

**Architecture:** Public V1 keeps release authority on the maintainer Mac: local scripts archive, sign, notarize, staple, verify, and prepare Sparkle metadata. The scripts must fail closed when run from the wrong Git source, when Sparkle tooling is unavailable, or when signatures lack secure timestamping. Full GitHub Actions release automation is documented as a later scaling item, not a Public V1 requirement.

**Tech Stack:** Swift Testing, bash release scripts, Xcode Developer ID export, Apple `codesign`/`notarytool`/`stapler`, Sparkle `generate_appcast`, GitHub Releases, GitHub Pages.

---

### Task 1: Lock Release Provenance To Merged Main

**Files:**
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/MacReleaseScriptTests.swift`
- Modify: `apps/mac/Scripts/verify-release-provenance.sh`
- Modify: `docs/release/public-v1-checklist.md`

- [x] **Step 1: Add failing script-shape assertions**

Require `verify-release-provenance.sh` to fetch `origin main`, require the current branch to be `main`, and require `HEAD` to equal `origin/main`.

Run:

```bash
cd apps/mac && swift test --filter MacReleaseScriptTests
```

Expected before implementation: FAIL because the script does not contain the new provenance fragments.

- [x] **Step 2: Implement fail-closed provenance checks**

Add the checks after the clean-worktree check and before tag validation:

```bash
git fetch --tags origin main
CURRENT_BRANCH="$(git branch --show-current)"
if [[ "$CURRENT_BRANCH" != "main" ]]; then
    printf 'Public releases must be created from main, not %s.\n' "${CURRENT_BRANCH:-detached HEAD}" >&2
    exit 65
fi
ORIGIN_MAIN_SHA="$(git rev-parse origin/main)"
HEAD_SHA="$(git rev-parse HEAD)"
if [[ "$HEAD_SHA" != "$ORIGIN_MAIN_SHA" ]]; then
    printf 'Public release HEAD must match origin/main.\n' >&2
    exit 65
fi
```

- [x] **Step 3: Document the enforced source rule**

In `docs/release/public-v1-checklist.md`, make the precondition explicit: signed releases are created only from a clean `main` checkout whose `HEAD` equals `origin/main`.

### Task 2: Make Sparkle Appcast Tool Discovery Reproducible

**Files:**
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/MacReleaseScriptTests.swift`
- Modify: `apps/mac/Scripts/generate-appcast.sh`
- Modify: `docs/release/public-v1-checklist.md`

- [x] **Step 1: Add failing assertions for Sparkle discovery**

Require `generate-appcast.sh` to auto-discover `generate_appcast` under Xcode DerivedData when `SPARKLE_BIN_DIR` is not provided.

Run:

```bash
cd apps/mac && swift test --filter MacReleaseScriptTests
```

Expected before implementation: FAIL because the script only uses `generate_appcast` from PATH or a manually supplied directory.

- [x] **Step 2: Implement discovery helper**

Add a helper that resolves tools in this order:

```bash
if [[ -n "$SPARKLE_BIN_DIR" ]]; then
    GENERATE_APPCAST="$SPARKLE_BIN_DIR/generate_appcast"
elif command -v generate_appcast >/dev/null 2>&1; then
    GENERATE_APPCAST="$(command -v generate_appcast)"
else
    GENERATE_APPCAST="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast' -type f -perm +111 -print -quit 2>/dev/null || true)"
fi
```

Use a portable executable check in the final script if `find -perm +111` is not supported by the active macOS shell environment.

- [x] **Step 3: Update appcast docs**

In `docs/release/public-v1-checklist.md`, state that the script auto-discovers Sparkle from PATH, `SPARKLE_BIN_DIR`, or Xcode DerivedData, and only needs `SPARKLE_BIN_DIR` when auto-discovery fails.

### Task 3: Require Explicit DMG Timestamping

**Files:**
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/MacReleaseScriptTests.swift`
- Modify: `apps/mac/Scripts/sign-dmg.sh`

- [x] **Step 1: Add failing assertion**

Require `sign-dmg.sh` to include `--timestamp` in the DMG signing command.

Run:

```bash
cd apps/mac && swift test --filter MacReleaseScriptTests
```

Expected before implementation: FAIL because the signing command lacks the explicit flag.

- [x] **Step 2: Add the flag**

Change the signing command to:

```bash
run_command codesign --force --timestamp --sign "$SIGNING_IDENTITY_FOR_COMMAND" "$DMG_PATH"
```

### Task 4: Record Future GitHub Actions Release Automation

**Files:**
- Modify: `docs/roadmap/development-roadmap.md`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/MacReleaseDocumentationTests.swift`

- [x] **Step 1: Add failing documentation assertion**

Require release documentation tests to find a future roadmap item for credential-gated GitHub Actions release automation.

Run:

```bash
cd apps/mac && swift test --filter MacReleaseDocumentationTests
```

Expected before implementation: FAIL because the roadmap does not mention full GitHub Actions release automation.

- [x] **Step 2: Add roadmap item**

Add a Stage 5D item that evaluates full GitHub Actions release automation after Public V1 is stable, including secure handling of Developer ID certificates, notary credentials, Sparkle EdDSA signing, release asset upload, appcast generation, and manual approval gates.

### Task 5: Verify

**Files:**
- No source edits.

- [x] **Step 1: Run focused Swift tests**

```bash
cd apps/mac && swift test --filter MacReleaseScriptTests && swift test --filter MacReleaseDocumentationTests
```

- [x] **Step 2: Run release dry-runs**

```bash
apps/mac/Scripts/rehearse-release.sh --version 0.1.0 --build 1 --mode dry-run
apps/mac/Scripts/sign-dmg.sh --dry-run --dmg apps/mac/.build/dmg/WhatTheToken-0.1.0.dmg
apps/mac/Scripts/generate-appcast.sh --dry-run --updates-dir /tmp/whatthetoken-updates --download-url-prefix https://github.com/hansDraisma/whatthetoken/releases/download/v0.1.0/
```

- [x] **Step 3: Run full relevant validation**

```bash
cd apps/mac && swift test
cd ../..
pnpm --filter @whatthetoken/core test
git diff --check
git status --short
```
