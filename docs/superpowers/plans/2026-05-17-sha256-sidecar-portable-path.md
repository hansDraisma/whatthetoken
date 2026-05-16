# SHA256 Sidecar Portable Path Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the `.sha256` sidecar shipped alongside the release DMG verifiable by downloaders, by recording only the DMG basename instead of the maintainer's absolute build path.

**Architecture:** Today `shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"` writes a line like `<hash>  /Users/<maintainer>/.../WhatTheToken-0.1.0.dmg`. Local `shasum -c` passes because the path resolves on the maintainer's disk, but a user who downloads `WhatTheToken-0.1.0.dmg` and `WhatTheToken-0.1.0.dmg.sha256` next to each other and runs `shasum -a 256 -c WhatTheToken-0.1.0.dmg.sha256` gets "No such file or directory" because the absolute path is not on their machine. The fix is to `cd` into the DMG's directory and run `shasum` on the basename so the sidecar records `<hash>  WhatTheToken-0.1.0.dmg`. Both the signed release script (`verify-release-artifacts.sh`) and the unsigned smoke script (`rehearse-release.sh`) must be updated together so the smoke and signed paths agree.

**Tech Stack:** bash, `shasum`, Swift Testing (`MacReleaseScriptTests`), `apps/mac/Scripts/*.sh`.

---

### Task 1: Lock The Portable-Sidecar Contract With Tests

**Files:**
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/MacReleaseScriptTests.swift`

- [ ] **Step 1: Add failing assertions for `verify-release-artifacts.sh`**

Locate the `("verify-release-artifacts.sh", [ ... ])` tuple (around `apps/mac/Tests/WhatTheTokenMacTests/MacReleaseScriptTests.swift:65-84`) and add these required fragments inside the existing array, immediately after the existing `"shasum -a 256 -c",` line:

```swift
"cd \"$(dirname \"$DMG_PATH\")\"",
"shasum -a 256 \"$(basename \"$DMG_PATH\")\"",
```

These fragments force the script to invoke `shasum` against the basename from inside the DMG's directory, which is what produces a portable sidecar. The existing `"shasum -a 256"` and `"shasum -a 256 -c"` fragments stay — together with the new fragments they pin both the algorithm and the call shape.

- [ ] **Step 2: Add failing assertions for `rehearse-release.sh`**

Inside the same `releaseScriptsUseExpectedToolsAndAvoidSecretEchoes` test, find the `("rehearse-release.sh", [ ... ])` tuple (around `apps/mac/Tests/WhatTheTokenMacTests/MacReleaseScriptTests.swift:106-124`) and add these required fragments to its array:

```swift
"cd \"$(dirname \"$DMG_PATH\")\"",
"shasum -a 256 \"$(basename \"$DMG_PATH\")\"",
```

These pin the same portable-sidecar contract on the unsigned smoke path so the smoke `.sha256` matches what a real downloader would see.

- [ ] **Step 3: Run the tests and confirm they fail for the right reason**

Run:

```bash
cd apps/mac && swift test --filter MacReleaseScriptTests
```

Expected: FAIL, with the failure message naming `verify-release-artifacts.sh` and `rehearse-release.sh` as missing the new `cd "$(dirname "$DMG_PATH")"` and basename fragments. If the test fails for any other reason (compile error, wrong tuple edited), fix the test edit before moving on.

- [ ] **Step 4: Commit the failing test**

```bash
git add apps/mac/Tests/WhatTheTokenMacTests/MacReleaseScriptTests.swift
git commit -m "test(mac): require sha256 sidecar to use basename, not absolute path"
```

### Task 2: Fix `verify-release-artifacts.sh` To Write A Portable Sidecar

**Files:**
- Modify: `apps/mac/Scripts/verify-release-artifacts.sh:128-135`

- [ ] **Step 1: Replace the checksum block with a basename-only invocation**

The current block reads:

```bash
checksum_path="$DMG_PATH.sha256"
if [[ "$DRY_RUN" -eq 1 ]]; then
    quote_command shasum -a 256 "$DMG_PATH" ">" "$checksum_path"
else
    shasum -a 256 "$DMG_PATH" > "$checksum_path"
    shasum -a 256 -c "$checksum_path"
    printf '%s\n' "$checksum_path"
fi
```

Replace it with:

```bash
checksum_path="$DMG_PATH.sha256"
if [[ "$DRY_RUN" -eq 1 ]]; then
    quote_command cd "$(dirname "$DMG_PATH")" "&&" shasum -a 256 "$(basename "$DMG_PATH")" ">" "$checksum_path"
else
    ( cd "$(dirname "$DMG_PATH")" && shasum -a 256 "$(basename "$DMG_PATH")" ) > "$checksum_path"
    ( cd "$(dirname "$DMG_PATH")" && shasum -a 256 -c "$(basename "$DMG_PATH").sha256" )
    printf '%s\n' "$checksum_path"
fi
```

Notes for the engineer:
- The subshell `( cd ... && shasum ... )` keeps the `cd` from leaking into the rest of the script.
- Redirecting the subshell's stdout into `$checksum_path` (which is an absolute path) writes the sidecar to the same location as before; only the *contents* change to use the bare basename.
- The `-c` verification step is also moved inside a subshell because it must run in the directory where the basename resolves; otherwise it would now fail with "No such file or directory" — the exact bug we are fixing.
- `quote_command` in the dry-run branch is preserved so dry-run output stays in the same `quote_command`-printed shape the existing tests and reviewers expect.

- [ ] **Step 2: Run the focused script test**

Run:

```bash
cd apps/mac && swift test --filter MacReleaseScriptTests
```

Expected: still FAIL, but the failure should now only mention `rehearse-release.sh`. If it still mentions `verify-release-artifacts.sh`, the new fragments are not present verbatim in that script — re-read the assertions in Task 1 Step 1 and align the script text exactly.

### Task 3: Fix `rehearse-release.sh` Unsigned Smoke Path

**Files:**
- Modify: `apps/mac/Scripts/rehearse-release.sh:73`

- [ ] **Step 1: Replace the smoke checksum line with a basename-only invocation**

The current line (inside the `unsigned-smoke)` case) reads:

```bash
shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"
```

Replace it with:

```bash
( cd "$(dirname "$DMG_PATH")" && shasum -a 256 "$(basename "$DMG_PATH")" ) > "$DMG_PATH.sha256"
```

Same rationale as Task 2: the subshell keeps `cd` local, and the redirection target stays an absolute path so the sidecar lands next to the DMG.

- [ ] **Step 2: Run the focused script test**

Run:

```bash
cd apps/mac && swift test --filter MacReleaseScriptTests
```

Expected: PASS. The portable-sidecar fragments now exist in both scripts.

### Task 4: End-To-End Verify The Fix Is Real

**Files:**
- No source edits.

- [ ] **Step 1: Run the unsigned smoke release end-to-end**

Run:

```bash
apps/mac/Scripts/rehearse-release.sh --version 0.1.0 --build 1 --mode unsigned-smoke
```

Expected: prints a DMG path under `apps/mac/.build/dmg-smoke/`. Capture it as `$DMG`.

- [ ] **Step 2: Inspect the sidecar contents**

Run:

```bash
cat "apps/mac/.build/dmg-smoke/WhatTheToken-0.1.0-unsigned-smoke.dmg.sha256"
```

Expected: a single line of the form `<64-hex-chars>  WhatTheToken-0.1.0-unsigned-smoke.dmg` — note the **bare basename**, no `/Users/...` prefix. If you see an absolute path, Task 3 Step 1 did not land — recheck.

- [ ] **Step 3: Verify the sidecar the way a downloader would**

Run:

```bash
cd apps/mac/.build/dmg-smoke && shasum -a 256 -c WhatTheToken-0.1.0-unsigned-smoke.dmg.sha256
```

Expected: `WhatTheToken-0.1.0-unsigned-smoke.dmg: OK`. This is the exact command shape published to users, and the assertion that the bug is fixed.

- [ ] **Step 4: Verify the signed-path script via dry-run**

Run:

```bash
apps/mac/Scripts/verify-release-artifacts.sh \
    --dmg apps/mac/.build/dmg/WhatTheToken-0.1.0.dmg \
    --app apps/mac/.build/export/WhatTheToken.app \
    --dry-run
```

Expected: the printed dry-run commands include a `cd "$(dirname "..."")" && shasum -a 256 "$(basename "..."")"` line in place of the old direct `shasum -a 256 <absolute-path>` line. No real DMG is required because `--dry-run` only prints.

- [ ] **Step 5: Run full focused validation**

Run:

```bash
cd apps/mac && swift test --filter MacReleaseScriptTests
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/mac/Scripts/verify-release-artifacts.sh apps/mac/Scripts/rehearse-release.sh
git commit -m "fix(mac): record only DMG basename in .sha256 sidecar

Downloaders verify with 'shasum -a 256 -c WhatTheToken-X.Y.Z.dmg.sha256'
next to the DMG, so the sidecar must reference the file by basename.
Previously it embedded the maintainer's absolute build path, which made
the published sidecar unverifiable for anyone else."
```

- [ ] **Step 7: Open the PR**

```bash
gh pr create --base main --title "fix(mac): portable .sha256 sidecar for release DMG" --body "$(cat <<'EOF'
## Summary
- \`shasum\` is now invoked against the DMG basename from inside its directory, so the published \`.sha256\` sidecar verifies for anyone who downloads it next to the DMG.
- Applies to both the signed verification path (\`verify-release-artifacts.sh\`) and the unsigned smoke path (\`rehearse-release.sh\`).
- Locks the contract with new \`MacReleaseScriptTests\` fragments so a regression to absolute paths fails the suite.

## Test plan
- [ ] \`cd apps/mac && swift test --filter MacReleaseScriptTests\`
- [ ] \`apps/mac/Scripts/rehearse-release.sh --version 0.1.0 --build 1 --mode unsigned-smoke\`
- [ ] \`cd apps/mac/.build/dmg-smoke && shasum -a 256 -c WhatTheToken-0.1.0-unsigned-smoke.dmg.sha256\` shows \`OK\`
- [ ] \`apps/mac/Scripts/verify-release-artifacts.sh --dmg <path> --app <path> --dry-run\` prints the new \`cd ... && shasum ...\` shape
EOF
)"
```

If the maintainer prefers to fold this into one of the two open release-hardening PRs instead of standing it alone, skip Step 7 and cherry-pick the Task 2, Task 3, and Task 1 commits onto that branch — the diff is self-contained and order-independent relative to the other hardening work.
