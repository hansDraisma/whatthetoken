# Stage 5 Documentation Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the release checklist, roadmap, and Stage 5 implementation-plan documentation into alignment with the refined Stage 5 release-readiness spec.

**Architecture:** Treat `docs/superpowers/specs/2026-05-09-distribution-hardening-design.md` as the source of truth. Update only the downstream docs that currently drift from it: the Public V1 release checklist, the canonical roadmap Stage 5 section, and the historical implementation plan status/checklist. Keep README and SECURITY unchanged unless verification finds a direct contradiction.

**Tech Stack:** Markdown docs, ripgrep verification scans, git diff review.

---

## File Structure

- Modify: `docs/release/public-v1-checklist.md` - align maintainer release checklist with Stage 5A/5B/5C, conditional Sparkle gates, app icon, Xcode first-launch, launch-at-login, and DMG inspection.
- Modify: `docs/roadmap/development-roadmap.md` - make Stage 5 status-aware and point to the Stage 5A/5B/5C release-readiness model.
- Modify: `docs/superpowers/plans/2026-05-09-distribution-hardening-and-sparkle.md` - mark completed repo-foundation tasks clearly and record remaining credentialed/manual gates without leaving misleading unchecked implementation boxes.

## Task 1: Update Public V1 Release Checklist

**Files:**
- Modify: `docs/release/public-v1-checklist.md`

- [ ] **Step 1: Make Sparkle preconditions conditional**

Edit the `Preconditions` section so Sparkle EdDSA material is not required for every Public V1 DMG. Replace:

```markdown
- Confirm Sparkle EdDSA private material is stored outside the repo and release hosting.
```

with:

```markdown
- If publishing an appcast or exposing `Check for Updates`, confirm Sparkle EdDSA private material is stored outside the repo and release hosting.
- If Sparkle remains hidden for Public V1, confirm `SUEnableAutomaticChecks` and `SUAutomaticallyUpdate` remain `false` and no update-checking UI is exposed.
```

- [ ] **Step 2: Add release readiness preconditions**

Add these bullets after the Keychain profile precondition:

```markdown
- Confirm Xcode first-launch packages are installed so `xcodebuild archive` can run.
- Confirm the release commit is clean, tagged, and matches the source used for archive/export.
- Confirm the public app icon and asset catalog are present before release rehearsal.
```

- [ ] **Step 3: Add Stage 5 gate overview**

Add this section after `Preconditions`:

```markdown
## Release Gates

- Stage 5A repo foundation: release target, metadata, scripts, tests, launch-at-login, Sparkle-ready wiring, and docs are committed.
- Stage 5B credentialed release rehearsal: a maintainer runs archive/export, signing, notarization, stapling, Gatekeeper verification, and fresh-machine smoke with real credentials.
- Stage 5C public launch: final DMG and checksum are published, docs point to the official artifacts, and repository visibility can flip without exposing internal paths or secret material.

Do not treat Stage 5A as a public release. Public V1 requires Stage 5B and Stage 5C.
```

- [ ] **Step 4: Expand fresh-machine smoke checks**

Replace the current GitHub Release smoke-test bullet:

```markdown
- Install the attached DMG on a fresh macOS account and smoke test launch, menu bar display, settings persistence, connector opt-in, disconnect, quit, and relaunch.
```

with:

```markdown
- Install the attached DMG on a fresh macOS account and smoke test launch, menu bar display, no Dock icon, settings persistence, connector opt-in, disconnect, quit, and relaunch.
- Confirm launch-at-login is off by default, toggles through Settings, and does not connect or refresh providers before consent.
- Inspect the mounted DMG and final artifacts for logs, diagnostics, internal workspace paths, untracked local files, raw provider output, or secret material.
```

- [ ] **Step 5: Add appcast publication ordering**

Add this bullet to `Before publishing appcast changes`:

```markdown
- Confirm the referenced artifact and checksum are already published before the appcast points to them.
```

- [ ] **Step 6: Run checklist drift scan**

Run:

```bash
rg -n "Sparkle EdDSA private material is stored outside|Stage 5A|Stage 5B|Stage 5C|Xcode first-launch|launch-at-login|Inspect the mounted DMG|referenced artifact" docs/release/public-v1-checklist.md
```

Expected: matches show conditional Sparkle wording and all new release gate/smoke checks.

- [ ] **Step 7: Commit checklist update**

```bash
git add docs/release/public-v1-checklist.md
git commit -m "docs: align Public V1 checklist with release gates"
```

## Task 2: Update Roadmap Stage 5 Status

**Files:**
- Modify: `docs/roadmap/development-roadmap.md`

- [ ] **Step 1: Add Stage 5 status note**

Under `### Stage 5: Distribution Hardening`, add:

```markdown
Status: Stage 5A repo foundation is implemented on the current Stage 5 branch. Public V1 still requires Stage 5B credentialed release rehearsal and Stage 5C public launch. The release-readiness source of truth is `docs/superpowers/specs/2026-05-09-distribution-hardening-design.md`.
```

- [ ] **Step 2: Replace future-only task list with gated task list**

Replace the Stage 5 `Tasks:` list with:

```markdown
Tasks:

- Maintain the distribution design covering entitlements, App Sandbox, signing, notarization, Sparkle, release secrets, and install/update UX.
- Keep Developer ID signing metadata, hardened runtime settings, minimal entitlements, notarization scripts, DMG packaging, release verification scripts, and the release checklist in sync with the release-readiness spec.
- Keep launch-at-login implemented through `SMAppService` as an explicit opt-in setting.
- Before Public V1, add the public app icon and asset catalog.
- Before Public V1, run a credentialed release rehearsal from a clean tagged commit.
- Generate and store Sparkle EdDSA private material outside the repo only before appcast publication or user-visible `Check for Updates`.
- Add `SUPublicEDKey` and `SUFeedURL` only after the public appcast URL and key custody are approved.
- Publish signed/notarized free DMG through GitHub Releases after Gatekeeper and fresh-machine smoke pass.
- Add Sparkle auto-update only after at least one stable signed manual update path is proven.
```

- [ ] **Step 3: Replace exit criteria with Stage 5B/5C criteria**

Replace the Stage 5 `Exit criteria:` list with:

```markdown
Exit criteria:

- A non-developer user can install the official DMG without Gatekeeper friction.
- The release app is Developer ID signed with hardened runtime enabled.
- The DMG is notarized, stapled, and accepted by Gatekeeper.
- Release process is documented and repeatable from a clean tagged commit.
- Signing, notarization, and Sparkle private material are not in the repo.
- Sparkle is either hidden with manual update docs, or exposed only after signed old-build to new-build update smoke passes.
- Repository visibility can flip to public after release docs and artifacts are checked.
```

- [ ] **Step 4: Expand verification list**

Replace the Stage 5 `Verification:` list with:

```markdown
Verification:

- TypeScript and Swift test suites pass.
- Xcode project and scheme parse cleanly.
- Xcode archive/export succeeds on a machine with Xcode first-launch packages installed.
- `spctl` assessment passes on the `.app` and DMG.
- Notarization ticket is stapled and validated.
- Fresh-machine install smoke covers launch, menu bar display, no Dock icon, settings, connector opt-in, disconnect, relaunch, and launch-at-login.
- Final DMG contents are inspected for logs, diagnostics, internal workspace paths, and secret material.
```

- [ ] **Step 5: Run roadmap drift scan**

Run:

```bash
rg -n "Stage 5A repo foundation|credentialed release rehearsal|future-only|Generate Sparkle EdDSA keypair before the first public signed release if Sparkle is planned|Add public Sparkle key to the app bundle even if auto-updates are enabled in a later release|Add Sparkle auto-update only after at least one stable signed release flow is proven" docs/roadmap/development-roadmap.md
```

Expected: the first two phrases match; the old unconditional Sparkle-key and future-only wording do not match.

- [ ] **Step 6: Update roadmap execution rule**

Replace the current execution rule sentence:

```markdown
Follow stages in order. Stage 0 through Stage 4 produce Internal V0. Stage 5 produces Public V1. Stages 6 and later should not start until the local product is useful, trusted, installable, and public.
```

with:

```markdown
Follow stages in order. Stage 0 through Stage 4 produce Internal V0. Stage 5 has three gates: Stage 5A repo foundation, Stage 5B credentialed release rehearsal, and Stage 5C public launch. Stages 6 and later should not start until Stage 5C exits and the local product is useful, trusted, installable, and public.
```

- [ ] **Step 7: Commit roadmap update**

```bash
git add docs/roadmap/development-roadmap.md
git commit -m "docs: update Stage 5 roadmap status"
```

## Task 3: Update Historical Implementation Plan Status

**Files:**
- Modify: `docs/superpowers/plans/2026-05-09-distribution-hardening-and-sparkle.md`

- [ ] **Step 1: Add completion legend**

After the existing `Implementation Status, 2026-05-09` paragraph, add:

```markdown
**Checklist Status:** Repo-foundation work is complete except for the Xcode Debug build verification step that is blocked in this workspace by local Xcode first-launch setup. Task 7 is partially complete: dependency install, TypeScript tests, Swift tests, project syntax checks, and release dry-runs passed; real `xcodebuild` archive/build, Developer ID signing, notarization, stapling, and Sparkle EdDSA signing remain blocked on local Xcode setup and maintainer credentials.
```

- [ ] **Step 2: Mark completed repo-foundation checkboxes complete**

Replace completed unchecked checkboxes under `Task 1` through `Task 6` from:

```markdown
- [ ] **Step
```

to:

```markdown
- [x] **Step
```

Keep the original Task 4 Xcode build verification unchecked because the build command did not pass in this workspace. Add this line directly under that original Xcode verification step:

```markdown
Status: blocked in the workspace by local Xcode first-launch package installation requiring privileged authorization before project loading.
```

Leave Task 7 steps unchecked unless the step is explicitly repo-verifiable and already done.

- [ ] **Step 3: Make Task 7 status explicit**

Under `## Task 7: Final Verification`, add:

```markdown
**Status:** Repo-verifiable checks have passed. Credentialed release verification is intentionally not complete in this workspace.
```

- [ ] **Step 4: Mark repo-verifiable Task 7 steps complete**

In Task 7, mark these steps complete:

```markdown
- [x] **Step 1: Install JS dependencies if missing**
- [x] **Step 2: Run full tests**
- [x] **Step 4: Run release-script dry-runs**
- [x] **Step 5: Document credential-gated verification**
```

Keep this step unchecked:

```markdown
- [ ] **Step 3: Run Xcode debug build**
```

Add this line directly under Step 3:

```markdown
Status: blocked in the workspace by local Xcode first-launch package installation requiring privileged authorization before project loading.
```

- [ ] **Step 5: Run implementation-plan status scan**

Run:

```bash
rg -n "\\- \\[ \\] \\*\\*Step|Checklist Status|Status: blocked in the workspace" docs/superpowers/plans/2026-05-09-distribution-hardening-and-sparkle.md
```

Expected: unchecked matches remain only for the original Task 4 Xcode build verification and Task 7 Step 3, plus any intentional explanatory heading text. `Checklist Status` and both Xcode blocked statuses match.

- [ ] **Step 6: Commit plan status update**

```bash
git add docs/superpowers/plans/2026-05-09-distribution-hardening-and-sparkle.md
git commit -m "docs: update distribution plan status"
```

## Task 4: Final Documentation Verification

**Files:**
- Verify all modified documentation.

- [ ] **Step 1: Run stale wording scan**

Run:

```bash
rg -n "Sparkle EdDSA private material is stored outside the repo and release hosting\\.|Add public Sparkle key to the app bundle even if auto-updates are enabled in a later release|Generate Sparkle EdDSA keypair before the first public signed release if Sparkle is planned|Stage 5 produces Public V1\\.|Stage 5 is complete when|future-only|TB""D|TO""DO" README.md SECURITY.md docs/release docs/roadmap docs/superpowers/specs/2026-05-09-distribution-hardening-design.md docs/superpowers/plans/2026-05-09-distribution-hardening-and-sparkle.md
```

Expected: no matches.

- [ ] **Step 2: Run secret-boundary wording scan**

Run:

```bash
rg -n "token|cookie|auth header|session|prompt|response|private key|notary password" docs/release README.md SECURITY.md docs/roadmap/development-roadmap.md
```

Expected: matches are warnings, privacy rules, or key-custody rules only. No actual secret values appear.

- [ ] **Step 3: Run whitespace verification**

Run:

```bash
git diff --check
```

Expected: no output and exit code 0.

- [ ] **Step 4: Review final diff**

Run:

```bash
git diff origin/main... -- docs/release/public-v1-checklist.md docs/roadmap/development-roadmap.md docs/superpowers/plans/2026-05-09-distribution-hardening-and-sparkle.md
```

Expected: checklist, roadmap, and implementation-plan status all use the Stage 5A/5B/5C model; Sparkle keys/feed are conditional; no doc claims Public V1 is released.

- [ ] **Step 5: Commit any final cleanup**

If Task 4 revealed fixes, commit them:

```bash
git add docs/release/public-v1-checklist.md docs/roadmap/development-roadmap.md docs/superpowers/plans/2026-05-09-distribution-hardening-and-sparkle.md
git commit -m "docs: finalize Stage 5 documentation sync"
```

If no fixes were needed, do not create an empty commit.
