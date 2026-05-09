# Phase 1 Core And Mac Counter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the foundation for a Mac-first developer AI consumption monitor by creating the shared quota domain package and a minimal SwiftUI status surface that renders a schema-valid usage snapshot.

**Architecture:** `packages/core` owns provider/product/surface types, usage event schemas, usage snapshot schemas, confidence labels, stale detection, and snapshot derivation. `apps/mac` owns the native SwiftUI app shell and initially renders fixture-backed snapshot data that mirrors the shared contract. Provider ingestion for Codex CLI and Claude Code is planned as feasibility spikes after the contract and first UI path exist.

**Tech Stack:** pnpm workspaces, TypeScript, Zod, Vitest, SwiftUI, Swift Package Manager, XCTest/Swift Testing where available.

---

## Constraints

- Use SwiftUI for the Mac product direction.
- Use TDD for behavior changes.
- Keep prompt/response/conversation/session data out of all models, logs, fixtures, and tests.
- Do not add Supabase, Next.js, or a browser extension in Phase 1.
- Do not implement real provider ingestion until the schema, core logic, and first Mac rendering path exist.

## File Structure

Create or modify these files:

- Create: `package.json` - root workspace scripts.
- Create: `pnpm-workspace.yaml` - workspace package map.
- Create: `tsconfig.base.json` - shared TypeScript compiler defaults.
- Create: `packages/core/package.json` - core package scripts and dependencies.
- Create: `packages/core/tsconfig.json` - core package TypeScript config.
- Create: `packages/core/vitest.config.ts` - Vitest config.
- Create: `packages/core/src/index.ts` - public exports.
- Create: `packages/core/src/types.ts` - provider/product/surface and confidence types.
- Create: `packages/core/src/schemas.ts` - Zod schemas for events and snapshots.
- Create: `packages/core/src/staleness.ts` - stale detection logic.
- Create: `packages/core/src/snapshots.ts` - snapshot derivation helpers.
- Create: `packages/core/src/fixtures.ts` - safe fixture builders.
- Create: `packages/core/src/fixture-files.ts` - reusable fixture JSON constants for app contract tests.
- Create: `packages/core/src/__tests__/schemas.test.ts` - schema tests.
- Create: `packages/core/src/__tests__/staleness.test.ts` - stale detection tests.
- Create: `packages/core/src/__tests__/snapshots.test.ts` - snapshot derivation tests.
- Create: `packages/core/src/__tests__/mac-fixture-contract.test.ts` - validates the Swift fixture against the shared Zod schema.
- Create: `apps/mac/Package.swift` - Swift package for the Mac app target.
- Create: `apps/mac/Sources/WhatTheTokenMac/WhatTheTokenApp.swift` - SwiftUI app entry.
- Create: `apps/mac/Sources/WhatTheTokenMac/Models/UsageSnapshot.swift` - Swift model mirroring the Phase 1 snapshot contract.
- Create: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift` - view model with fixture loading.
- Create: `apps/mac/Sources/WhatTheTokenMac/Views/StatusCardView.swift` - reusable quota/status card.
- Create: `apps/mac/Sources/WhatTheTokenMac/Views/ContentView.swift` - app content root.
- Create: `apps/mac/Sources/WhatTheTokenMac/Resources/usage-snapshot.fixture.json` - safe local fixture.
- Create: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift` - Swift model/view-model tests.
- Create: `docs/research/codex-cli-local-signal-spike.md` - Codex CLI feasibility findings.
- Create: `docs/research/claude-code-local-signal-spike.md` - Claude Code feasibility findings.
- Modify: `.gitignore` - add Node, Swift, and Xcode build outputs.
- Modify: `docs/agent/operating-rules.md` - keep SwiftUI direction and TDD rules visible.
- Modify: `docs/architecture/tech-stack-and-development-approach.md` - keep stack decisions current if implementation reveals a necessary adjustment.

## Task 1: Root Workspace Foundation

**Purpose:** Establish the monorepo contract that all later TypeScript, Swift, documentation, and research worktrees build on. This task is a dependency barrier: do not start Task 2 or any parallel worktrees until this task is merged or otherwise available as the base for those worktrees.

**Files:**
- Create: `package.json`
- Create: `pnpm-workspace.yaml`
- Create: `tsconfig.base.json`
- Modify: `.gitignore`
- Create: `pnpm-lock.yaml`

**Non-goals:**
- Do not create `packages/core`, `apps/mac`, provider ingestion code, app code, or documentation beyond the root workspace files listed above.
- Do not add Supabase, Next.js, browser extension tooling, analytics, or build orchestration.
- Do not commit unrelated formatting, generated files, local tool output, or machine-specific IDE metadata.

**Acceptance criteria:**
- `pnpm --version` is checked before install and must equal `10.0.0`, matching `packageManager: pnpm@10.0.0`; any mismatch is resolved with Corepack before continuing.
- `pnpm install` creates or updates only the expected workspace dependency files, especially `pnpm-lock.yaml`.
- `pnpm check` is run and its exact output is captured in the worker summary.
- A `pnpm check` failure is acceptable only when it is caused by the intentional absence of package-level workspace scripts/packages at this stage. Any install, lockfile, TypeScript configuration, or unexpected script failure blocks Task 2.
- `git status --short` shows only the intentional Task 1 files before commit.
- Later parallel worktrees branch from a base that includes this task.

**Status:** Complete in commit `4d90c89 chore: scaffold workspace`.

**Verification evidence:**
- `pnpm --version` printed `10.0.0`.
- `pnpm install` completed with the lockfile already up to date.
- `pnpm check` passed after dependencies were installed.
- `git status --short` was clean before this documentation correction.

- [x] **Step 1: Write root workspace files**

Create `package.json`:

```json
{
  "name": "whatthetoken",
  "private": true,
  "version": "0.0.0",
  "packageManager": "pnpm@10.0.0",
  "scripts": {
    "typecheck": "pnpm -r typecheck",
    "test": "pnpm -r test",
    "lint": "pnpm -r lint",
    "check": "pnpm typecheck && pnpm test && pnpm lint"
  },
  "devDependencies": {
    "typescript": "^5.9.0"
  }
}
```

Create `pnpm-workspace.yaml`:

```yaml
packages:
  - "packages/*"
  - "apps/*"
```

Create `tsconfig.base.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022"],
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  }
}
```

Update `.gitignore` to include:

```gitignore
.superpowers/
.DS_Store
node_modules/
dist/
coverage/
.turbo/
.pnpm-store/
.build/
DerivedData/
*.xcuserdata/
*.xcodeproj/project.xcworkspace/xcuserdata/
```

- [x] **Step 2: Verify package-manager availability**

Run:

```bash
pnpm --version
```

Expected: `pnpm --version` prints exactly `10.0.0`, matching `packageManager: pnpm@10.0.0`.

If pnpm is missing or prints any other version, prefer Corepack:

```bash
corepack enable
corepack prepare pnpm@10.0.0 --activate
pnpm --version
```

Record the final `pnpm --version` output in the worker summary. Do not proceed if pnpm cannot be made available at exactly `10.0.0`.

- [x] **Step 3: Install workspace dependencies**

Run:

```bash
pnpm install
```

Expected: lockfile created successfully.

Review the resulting file set:

```bash
git status --short
```

Expected: only Task 1 files are new or modified. `pnpm-lock.yaml` should be the only generated dependency artifact. If `pnpm install` creates unrelated files or changes documentation/source files, stop and investigate before continuing.

- [x] **Step 4: Run root check and classify the result**

Run:

```bash
pnpm check
```

Expected: this may fail because no workspace package exists yet. Capture the exact output in the worker summary.

Continue only if the failure is limited to the expected empty-workspace/no-package-scripts state. Stop if the failure points to package-manager setup, dependency resolution, lockfile corruption, TypeScript config parse errors, or any unexpected script behavior.

- [x] **Step 5: Final pre-commit review**

Run:

```bash
git status --short
git diff -- package.json pnpm-workspace.yaml tsconfig.base.json .gitignore pnpm-lock.yaml
```

Expected: only the root workspace contract files and `pnpm-lock.yaml` are staged or unstaged. The diff should not include package/app code, provider research, credentials, local logs, IDE state, or generated build outputs.

- [x] **Step 6: Commit**

```bash
git add package.json pnpm-workspace.yaml tsconfig.base.json .gitignore pnpm-lock.yaml
git commit -m "chore: scaffold workspace"
```

After commit, hand off this branch as the base for Task 2, Task 5, Task 7, Task 8, and Task 9 worktrees. Do not let downstream worktrees start from a base that lacks this commit.

## Task 2: Core Package Schemas

**Files:**
- Create: `packages/core/package.json`
- Create: `packages/core/tsconfig.json`
- Create: `packages/core/vitest.config.ts`
- Create: `packages/core/src/index.ts`
- Create: `packages/core/src/types.ts`
- Create: `packages/core/src/schemas.ts`
- Test: `packages/core/src/__tests__/schemas.test.ts`

**Status:** Complete in commit `ade0ea8 feat(core): add usage schemas`, with follow-up review fixes applied in this branch.

**Review follow-up evidence:**
- `usageEventSchema.count` rejects fractional event counts.
- `@whatthetoken/core` has a `build` script and explicit package exports for emitted `dist` files.
- Internal runtime imports use `.js` specifiers so the emitted ESM package can be imported by Node.
- `pnpm --filter @whatthetoken/core build` passed.
- `node --input-type=module -e "import('@whatthetoken/core')..."` passed from `packages/core` after build.
- `pnpm check` passed with 4 test files and 14 tests.

- [x] **Step 1: Write failing schema tests**

Create `packages/core/src/__tests__/schemas.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { usageEventSchema, usageSnapshotSchema } from "../schemas";

describe("usage schemas", () => {
  it("accepts a sanitized Codex CLI usage event", () => {
    const parsed = usageEventSchema.parse({
      id: "evt_01",
      userAccountId: "user_01",
      deviceId: "device_mac_01",
      providerAccountId: "openai_personal",
      provider: "openai",
      product: "codex",
      surface: "cli",
      eventType: "agent_run_started",
      modelKey: "gpt-5.3-codex",
      count: 1,
      observedAt: "2026-05-04T10:00:00.000Z",
      confidence: "observed",
      sourceVersion: "codex-cli-local-v1",
      attribution: {
        deviceName: "Hans MacBook",
        os: "macos",
        canMissOtherDevices: true
      }
    });

    expect(parsed.product).toBe("codex");
    expect(parsed.confidence).toBe("observed");
  });

  it("rejects prompt or conversation fields", () => {
    expect(() =>
      usageEventSchema.parse({
        id: "evt_02",
        userAccountId: "user_01",
        deviceId: "device_mac_01",
        providerAccountId: "openai_personal",
        provider: "openai",
        product: "codex",
        surface: "cli",
        eventType: "agent_run_started",
        modelKey: "gpt-5.3-codex",
        count: 1,
        observedAt: "2026-05-04T10:00:00.000Z",
        confidence: "observed",
        sourceVersion: "codex-cli-local-v1",
        prompt: "do not collect this",
        attribution: {
          os: "macos",
          canMissOtherDevices: true
        }
      })
    ).toThrow();
  });

  it("rejects fractional event counts", () => {
    expect(() =>
      usageEventSchema.parse({
        id: "evt_fractional",
        userAccountId: "user_01",
        deviceId: "device_mac_01",
        providerAccountId: "openai_personal",
        provider: "openai",
        product: "codex",
        surface: "cli",
        eventType: "message_sent",
        modelKey: "gpt-5.3-codex",
        count: 0.5,
        observedAt: "2026-05-04T10:00:00.000Z",
        confidence: "observed",
        sourceVersion: "codex-cli-local-v1",
        attribution: {
          os: "macos",
          canMissOtherDevices: true
        }
      })
    ).toThrow();
  });

  it("accepts a pool-aware Claude Code snapshot", () => {
    const parsed = usageSnapshotSchema.parse({
      id: "snap_01",
      userAccountId: "user_01",
      provider: "anthropic",
      product: "claude_code",
      surface: "cli",
      poolKey: "anthropic_claude_subscription",
      windowKey: "five_hour",
      unit: "utilization",
      used: 62,
      limit: 100,
      remaining: 38,
      utilization: 0.62,
      resetAt: "2026-05-04T15:00:00.000Z",
      lastUpdatedAt: "2026-05-04T10:00:00.000Z",
      confidence: "verified",
      undercountRisk: "possible",
      staleReason: null
    });

    expect(parsed.poolKey).toBe("anthropic_claude_subscription");
    expect(parsed.confidence).toBe("verified");
  });

  it("rejects inconsistent snapshot math", () => {
    expect(() =>
      usageSnapshotSchema.parse({
        id: "snap_bad_math",
        userAccountId: "user_01",
        provider: "anthropic",
        product: "claude_code",
        surface: "cli",
        poolKey: "anthropic_claude_subscription",
        windowKey: "five_hour",
        unit: "utilization",
        used: 62,
        limit: 100,
        remaining: -4,
        utilization: 2,
        resetAt: "2026-05-04T15:00:00.000Z",
        lastUpdatedAt: "2026-05-04T10:00:00.000Z",
        confidence: "verified",
        undercountRisk: "possible",
        staleReason: null
      })
    ).toThrow();
  });
});
```

- [x] **Step 2: Run test to verify it fails**

Run:

```bash
pnpm --filter @whatthetoken/core test -- schemas.test.ts
```

Expected: FAIL because `@whatthetoken/core`, schemas, and test config do not exist yet.

- [x] **Step 3: Add package config**

Create `packages/core/package.json`:

```json
{
  "name": "@whatthetoken/core",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "main": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "import": "./dist/index.js"
    }
  },
  "scripts": {
    "build": "tsc",
    "typecheck": "tsc --noEmit",
    "test": "vitest run",
    "lint": "tsc --noEmit"
  },
  "dependencies": {
    "zod": "^4.0.0"
  },
  "devDependencies": {
    "@types/node": "^24.0.0",
    "vitest": "^4.0.0"
  }
}
```

Create `packages/core/tsconfig.json`:

```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "rootDir": "src",
    "outDir": "dist",
    "declaration": true
  },
  "include": ["src"]
}
```

Create `packages/core/vitest.config.ts`:

```ts
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    include: ["src/**/*.test.ts"]
  }
});
```

- [x] **Step 4: Add schema implementation**

Create `packages/core/src/types.ts`:

```ts
export type Provider = "openai" | "anthropic" | "google" | "cursor" | "github";

export type Product =
  | "codex"
  | "chatgpt"
  | "claude_code"
  | "claude"
  | "gemini"
  | "cursor"
  | "github_copilot";

export type Surface =
  | "cli"
  | "web"
  | "browser_extension"
  | "desktop_app"
  | "ide"
  | "cloud_agent"
  | "mobile";

export type UsageConfidence = "verified" | "observed" | "estimated" | "stale";
export type UsageUnit = "messages" | "requests" | "tokens" | "credits" | "utilization";
export type UndercountRisk = "none" | "possible" | "likely";
```

Create `packages/core/src/schemas.ts`:

```ts
import { z } from "zod";

export const providerSchema = z.enum(["openai", "anthropic", "google", "cursor", "github"]);
export const productSchema = z.enum([
  "codex",
  "chatgpt",
  "claude_code",
  "claude",
  "gemini",
  "cursor",
  "github_copilot"
]);
export const surfaceSchema = z.enum([
  "cli",
  "web",
  "browser_extension",
  "desktop_app",
  "ide",
  "cloud_agent",
  "mobile"
]);
export const confidenceSchema = z.enum(["verified", "observed", "estimated", "stale"]);
export const usageUnitSchema = z.enum(["messages", "requests", "tokens", "credits", "utilization"]);
export const undercountRiskSchema = z.enum(["none", "possible", "likely"]);

export const attributionSchema = z
  .object({
    deviceName: z.string().min(1).optional(),
    os: z.enum(["macos", "windows", "linux", "ios", "android", "unknown"]).optional(),
    browser: z.enum(["chrome", "edge", "brave", "firefox", "safari", "unknown"]).optional(),
    canMissOtherDevices: z.boolean()
  })
  .strict();

export const usageEventSchema = z
  .object({
    id: z.string().min(1),
    userAccountId: z.string().min(1),
    deviceId: z.string().min(1),
    providerAccountId: z.string().min(1).nullable(),
    provider: providerSchema,
    product: productSchema,
    surface: surfaceSchema,
    eventType: z.enum(["message_sent", "agent_run_started", "agent_run_finished", "quota_polled"]),
    modelKey: z.string().min(1).nullable(),
    count: z.number().int().nonnegative(),
    observedAt: z.string().datetime(),
    confidence: confidenceSchema,
    sourceVersion: z.string().min(1),
    attribution: attributionSchema
  })
  .strict();

export const usageSnapshotSchema = z
  .object({
    id: z.string().min(1),
    userAccountId: z.string().min(1),
    provider: providerSchema,
    product: productSchema,
    surface: z.union([surfaceSchema, z.literal("aggregate")]),
    poolKey: z.string().min(1),
    windowKey: z.string().min(1),
    unit: usageUnitSchema,
    used: z.number().nonnegative().nullable(),
    limit: z.number().positive().nullable(),
    remaining: z.number().nonnegative().nullable(),
    utilization: z.number().min(0).nullable(),
    resetAt: z.string().datetime().nullable(),
    lastUpdatedAt: z.string().datetime(),
    confidence: confidenceSchema,
    undercountRisk: undercountRiskSchema,
    staleReason: z.string().min(1).nullable()
  })
  .strict()
  .superRefine((snapshot, context) => {
    if (snapshot.used !== null && snapshot.limit !== null) {
      const expectedRemaining = Math.max(snapshot.limit - snapshot.used, 0);
      const expectedUtilization = snapshot.used / snapshot.limit;

      if (snapshot.remaining !== expectedRemaining) {
        context.addIssue({
          code: "custom",
          path: ["remaining"],
          message: "remaining must equal max(limit - used, 0)"
        });
      }

      if (snapshot.utilization !== expectedUtilization) {
        context.addIssue({
          code: "custom",
          path: ["utilization"],
          message: "utilization must equal used / limit"
        });
      }
    }

    if ((snapshot.used === null || snapshot.limit === null) && snapshot.remaining !== null) {
      context.addIssue({
        code: "custom",
        path: ["remaining"],
        message: "remaining must be null when used or limit is unknown"
      });
    }

    if ((snapshot.used === null || snapshot.limit === null) && snapshot.utilization !== null) {
      context.addIssue({
        code: "custom",
        path: ["utilization"],
        message: "utilization must be null when used or limit is unknown"
      });
    }
  });

export type UsageEvent = z.infer<typeof usageEventSchema>;
export type UsageSnapshot = z.infer<typeof usageSnapshotSchema>;
```

Create `packages/core/src/index.ts`:

```ts
export * from "./types.js";
export * from "./schemas.js";
```

- [x] **Step 5: Run schema tests**

Run:

```bash
pnpm install
pnpm --filter @whatthetoken/core test -- schemas.test.ts
```

Expected: PASS.

- [x] **Step 6: Run core typecheck**

Run:

```bash
pnpm --filter @whatthetoken/core typecheck
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add package.json pnpm-lock.yaml pnpm-workspace.yaml tsconfig.base.json packages/core
git commit -m "feat(core): add usage schemas"
```

## Task 3: Staleness Logic

**Status:** Complete in `f45177b` (`feat(core): add staleness evaluation`) and reverified on 2026-05-04.

**Verification evidence:**
- `pnpm --filter @whatthetoken/core test -- staleness.test.ts` passed with 4 test files and 14 tests.
- `pnpm check` passed.

**Files:**
- Create: `packages/core/src/staleness.ts`
- Test: `packages/core/src/__tests__/staleness.test.ts`
- Modify: `packages/core/src/index.ts`

- [ ] **Step 1: Write failing tests**

Create `packages/core/src/__tests__/staleness.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { evaluateStaleness } from "../staleness";

describe("evaluateStaleness", () => {
  it("keeps fresh observed snapshots unchanged", () => {
    const result = evaluateStaleness({
      confidence: "observed",
      lastUpdatedAt: "2026-05-04T10:00:00.000Z",
      now: "2026-05-04T10:03:00.000Z",
      staleAfterMinutes: 10
    });

    expect(result.confidence).toBe("observed");
    expect(result.staleReason).toBeNull();
  });

  it("marks old snapshots as stale", () => {
    const result = evaluateStaleness({
      confidence: "verified",
      lastUpdatedAt: "2026-05-04T10:00:00.000Z",
      now: "2026-05-04T10:12:00.000Z",
      staleAfterMinutes: 10
    });

    expect(result.confidence).toBe("stale");
    expect(result.staleReason).toBe("Last update was 12 minutes ago.");
  });

  it("marks invalid timestamps as stale", () => {
    const result = evaluateStaleness({
      confidence: "verified",
      lastUpdatedAt: "not-a-date",
      now: "2026-05-04T10:12:00.000Z",
      staleAfterMinutes: 10
    });

    expect(result.confidence).toBe("stale");
    expect(result.staleReason).toBe("Last update timestamp is invalid.");
  });

  it("marks future timestamps as stale", () => {
    const result = evaluateStaleness({
      confidence: "observed",
      lastUpdatedAt: "2026-05-04T10:13:00.000Z",
      now: "2026-05-04T10:12:00.000Z",
      staleAfterMinutes: 10
    });

    expect(result.confidence).toBe("stale");
    expect(result.staleReason).toBe("Last update timestamp is in the future.");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
pnpm --filter @whatthetoken/core test -- staleness.test.ts
```

Expected: FAIL because `evaluateStaleness` does not exist.

- [ ] **Step 3: Implement staleness helper**

Create `packages/core/src/staleness.ts`:

```ts
import type { UsageConfidence } from "./types";

type EvaluateStalenessInput = {
  confidence: Exclude<UsageConfidence, "stale">;
  lastUpdatedAt: string;
  now: string;
  staleAfterMinutes: number;
};

type EvaluateStalenessResult = {
  confidence: UsageConfidence;
  staleReason: string | null;
};

export function evaluateStaleness(input: EvaluateStalenessInput): EvaluateStalenessResult {
  const lastUpdatedMs = Date.parse(input.lastUpdatedAt);
  const nowMs = Date.parse(input.now);

  if (Number.isNaN(lastUpdatedMs) || Number.isNaN(nowMs)) {
    return {
      confidence: "stale",
      staleReason: "Last update timestamp is invalid."
    };
  }

  if (lastUpdatedMs > nowMs) {
    return {
      confidence: "stale",
      staleReason: "Last update timestamp is in the future."
    };
  }

  const ageMinutes = Math.floor((nowMs - lastUpdatedMs) / 60_000);

  if (ageMinutes > input.staleAfterMinutes) {
    return {
      confidence: "stale",
      staleReason: `Last update was ${ageMinutes} minutes ago.`
    };
  }

  return {
    confidence: input.confidence,
    staleReason: null
  };
}
```

Update `packages/core/src/index.ts`:

```ts
export * from "./types.js";
export * from "./schemas.js";
export * from "./staleness.js";
```

- [ ] **Step 4: Run tests**

Run:

```bash
pnpm --filter @whatthetoken/core test -- staleness.test.ts
```

Expected: PASS.

- [ ] **Step 5: Run core checks**

Run:

```bash
pnpm --filter @whatthetoken/core typecheck
pnpm --filter @whatthetoken/core test
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add packages/core/src/staleness.ts packages/core/src/index.ts packages/core/src/__tests__/staleness.test.ts
git commit -m "feat(core): add staleness evaluation"
```

## Task 4: Snapshot Derivation

**Status:** Complete in `ac6acff` (`feat(core): derive usage snapshots`) and reverified on 2026-05-04.

**Verification evidence:**
- `pnpm check` passed with core schema, staleness, snapshot, and Mac fixture contract tests.

**Files:**
- Create: `packages/core/src/snapshots.ts`
- Create: `packages/core/src/fixtures.ts`
- Test: `packages/core/src/__tests__/snapshots.test.ts`
- Modify: `packages/core/src/index.ts`

- [ ] **Step 1: Write failing tests**

Create `packages/core/src/__tests__/snapshots.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { createSnapshotFromQuotaPoll } from "../snapshots";

describe("createSnapshotFromQuotaPoll", () => {
  it("creates a verified Claude Code utilization snapshot", () => {
    const snapshot = createSnapshotFromQuotaPoll({
      id: "snap_claude_01",
      userAccountId: "user_01",
      provider: "anthropic",
      product: "claude_code",
      surface: "cli",
      poolKey: "anthropic_claude_subscription",
      windowKey: "five_hour",
      unit: "utilization",
      used: 62,
      limit: 100,
      resetAt: "2026-05-04T15:00:00.000Z",
      lastUpdatedAt: "2026-05-04T10:00:00.000Z",
      confidence: "verified",
      undercountRisk: "possible"
    });

    expect(snapshot.remaining).toBe(38);
    expect(snapshot.utilization).toBe(0.62);
    expect(snapshot.staleReason).toBeNull();
  });

  it("supports observed Codex credit usage without a known hard limit", () => {
    const snapshot = createSnapshotFromQuotaPoll({
      id: "snap_codex_01",
      userAccountId: "user_01",
      provider: "openai",
      product: "codex",
      surface: "cli",
      poolKey: "openai_codex_included_usage",
      windowKey: "monthly",
      unit: "credits",
      used: 12.5,
      limit: null,
      resetAt: null,
      lastUpdatedAt: "2026-05-04T10:00:00.000Z",
      confidence: "observed",
      undercountRisk: "possible"
    });

    expect(snapshot.remaining).toBeNull();
    expect(snapshot.utilization).toBeNull();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
pnpm --filter @whatthetoken/core test -- snapshots.test.ts
```

Expected: FAIL because `createSnapshotFromQuotaPoll` does not exist.

- [ ] **Step 3: Implement snapshot derivation**

Create `packages/core/src/snapshots.ts`:

```ts
import type { Product, Provider, Surface, UndercountRisk, UsageConfidence, UsageUnit } from "./types";
import type { UsageSnapshot } from "./schemas";

type CreateSnapshotInput = {
  id: string;
  userAccountId: string;
  provider: Provider;
  product: Product;
  surface: Surface | "aggregate";
  poolKey: string;
  windowKey: string;
  unit: UsageUnit;
  used: number | null;
  limit: number | null;
  resetAt: string | null;
  lastUpdatedAt: string;
  confidence: UsageConfidence;
  undercountRisk: UndercountRisk;
};

export function createSnapshotFromQuotaPoll(input: CreateSnapshotInput): UsageSnapshot {
  const remaining =
    input.used === null || input.limit === null ? null : Math.max(input.limit - input.used, 0);

  const utilization =
    input.used === null || input.limit === null ? null : input.used / input.limit;

  return {
    ...input,
    remaining,
    utilization,
    staleReason: null
  };
}
```

Create `packages/core/src/fixtures.ts`:

```ts
import { createSnapshotFromQuotaPoll } from "./snapshots.js";

export function createClaudeCodeFixtureSnapshot() {
  return createSnapshotFromQuotaPoll({
    id: "snap_claude_fixture",
    userAccountId: "fixture_user",
    provider: "anthropic",
    product: "claude_code",
    surface: "cli",
    poolKey: "anthropic_claude_subscription",
    windowKey: "five_hour",
    unit: "utilization",
    used: 62,
    limit: 100,
    resetAt: "2026-05-04T15:00:00.000Z",
    lastUpdatedAt: "2026-05-04T10:00:00.000Z",
    confidence: "verified",
    undercountRisk: "possible"
  });
}
```

Create `packages/core/src/fixture-files.ts`:

```ts
import { createClaudeCodeFixtureSnapshot } from "./fixtures.js";

export const claudeCodeFixtureSnapshotJson = JSON.stringify(
  createClaudeCodeFixtureSnapshot(),
  null,
  2
);
```

Update `packages/core/src/index.ts`:

```ts
export * from "./types.js";
export * from "./schemas.js";
export * from "./staleness.js";
export * from "./snapshots.js";
export * from "./fixtures.js";
export * from "./fixture-files.js";
```

- [ ] **Step 4: Run tests**

Run:

```bash
pnpm --filter @whatthetoken/core test -- snapshots.test.ts
```

Expected: PASS.

- [ ] **Step 5: Run core checks**

Run:

```bash
pnpm --filter @whatthetoken/core typecheck
pnpm --filter @whatthetoken/core test
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add packages/core/src/snapshots.ts packages/core/src/fixtures.ts packages/core/src/fixture-files.ts packages/core/src/index.ts packages/core/src/__tests__/snapshots.test.ts
git commit -m "feat(core): derive usage snapshots"
```

## Task 5: SwiftUI Mac App Shell With Fixture Card

**Status:** Completed in `ebcb7cf` (`feat(mac): render fixture usage status`) and reverified on 2026-05-04 after rebasing onto `origin/main`.

**Verification:**
- `cd apps/mac && swift test` passed with 1 Swift Testing test.
- `cd apps/mac && swift build` passed.
- `pnpm --filter @whatthetoken/core test -- mac-fixture-contract.test.ts` passed with 4 test files and 13 tests.
- `pnpm check` passed.

**Reviewed gaps closed by Task 5A:**
- Task 5 proved the Swift package builds and the fixture decodes, but it did not assert the rendered card strings. Task 5A added a small display-model seam so the card title, primary metric, confidence label, updated label, and progress value are tested without snapshot-testing SwiftUI internals.
- The shipped Swift test name said "WithoutSensitiveContent" but only asserted decoded quota fields. Task 5A renamed the test and added a recursive fixture JSON scan for disallowed sensitive keys.

**Files:**
- Create: `apps/mac/Package.swift`
- Create: `apps/mac/Sources/WhatTheTokenMac/WhatTheTokenApp.swift`
- Create: `apps/mac/Sources/WhatTheTokenMac/Models/UsageSnapshot.swift`
- Create: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift`
- Create: `apps/mac/Sources/WhatTheTokenMac/Views/StatusCardView.swift`
- Create: `apps/mac/Sources/WhatTheTokenMac/Views/ContentView.swift`
- Create: `apps/mac/Sources/WhatTheTokenMac/Resources/usage-snapshot.fixture.json`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift`

- [x] **Step 1: Write failing Swift tests**

Create `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift`:

```swift
import Testing
@testable import WhatTheTokenMac

@Test func loadsFixtureSnapshotWithoutSensitiveContent() throws {
    let snapshot = try StatusViewModel.loadFixtureSnapshot()

    #expect(snapshot.product == "claude_code")
    #expect(snapshot.confidence == "verified")
    #expect(snapshot.remaining == 38)
    #expect(snapshot.staleReason == nil)
}
```

- [x] **Step 2: Run test to verify it fails**

Run:

```bash
cd apps/mac
swift test
```

Expected: FAIL because the Swift package and app code do not exist yet.

- [x] **Step 3: Add Swift package**

Create `apps/mac/Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WhatTheTokenMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "WhatTheTokenMac", targets: ["WhatTheTokenMac"])
    ],
    targets: [
        .executableTarget(
            name: "WhatTheTokenMac",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "WhatTheTokenMacTests",
            dependencies: ["WhatTheTokenMac"]
        )
    ]
)
```

- [x] **Step 4: Add Swift models and fixture**

Create `apps/mac/Sources/WhatTheTokenMac/Models/UsageSnapshot.swift`:

```swift
import Foundation

struct UsageSnapshot: Codable, Equatable, Sendable {
    let id: String
    let userAccountId: String
    let provider: String
    let product: String
    let surface: String
    let poolKey: String
    let windowKey: String
    let unit: String
    let used: Double?
    let limit: Double?
    let remaining: Double?
    let utilization: Double?
    let resetAt: String?
    let lastUpdatedAt: String
    let confidence: String
    let undercountRisk: String
    let staleReason: String?
}
```

Create `apps/mac/Sources/WhatTheTokenMac/Resources/usage-snapshot.fixture.json`:

```json
{
  "id": "snap_claude_fixture",
  "userAccountId": "fixture_user",
  "provider": "anthropic",
  "product": "claude_code",
  "surface": "cli",
  "poolKey": "anthropic_claude_subscription",
  "windowKey": "five_hour",
  "unit": "utilization",
  "used": 62,
  "limit": 100,
  "remaining": 38,
  "utilization": 0.62,
  "resetAt": "2026-05-04T15:00:00.000Z",
  "lastUpdatedAt": "2026-05-04T10:00:00.000Z",
  "confidence": "verified",
  "undercountRisk": "possible",
  "staleReason": null
}
```

- [x] **Step 5: Add view model**

Create `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift`:

```swift
import Foundation
import Observation

@Observable
final class StatusViewModel {
    var snapshots: [UsageSnapshot]

    init(snapshots: [UsageSnapshot] = []) {
        self.snapshots = snapshots
    }

    static func loadFixtureSnapshot() throws -> UsageSnapshot {
        guard let url = Bundle.module.url(forResource: "usage-snapshot.fixture", withExtension: "json") else {
            throw FixtureError.missingFixture
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(UsageSnapshot.self, from: data)
    }

    static func fixture() -> StatusViewModel {
        do {
            return StatusViewModel(snapshots: [try loadFixtureSnapshot()])
        } catch {
            return StatusViewModel(snapshots: [])
        }
    }
}

enum FixtureError: Error {
    case missingFixture
}
```

- [x] **Step 6: Add SwiftUI views**

Create `apps/mac/Sources/WhatTheTokenMac/Views/StatusCardView.swift`:

```swift
import SwiftUI

struct StatusCardView: View {
    let snapshot: UsageSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(snapshot.confidence.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Text(primaryMetric)
                .font(.system(size: 28, weight: .semibold))

            ProgressView(value: snapshot.utilization ?? 0)
                .progressViewStyle(.linear)

            Text("Updated \(snapshot.lastUpdatedAt)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 320, alignment: .leading)
    }

    private var title: String {
        "\(snapshot.provider.capitalized) / \(snapshot.product.replacingOccurrences(of: "_", with: " "))"
    }

    private var primaryMetric: String {
        guard let remaining = snapshot.remaining else {
            return "Usage observed"
        }

        switch snapshot.unit {
        case "utilization":
            return "\(Int(remaining))% remaining"
        case "credits":
            return "\(remaining.formatted()) credits remaining"
        case "tokens":
            return "\(Int(remaining)) tokens remaining"
        case "requests":
            return "\(Int(remaining)) requests remaining"
        case "messages":
            return "\(Int(remaining)) messages remaining"
        default:
            return "\(remaining.formatted()) remaining"
        }
    }
}
```

Create `apps/mac/Sources/WhatTheTokenMac/Views/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    let viewModel: StatusViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.snapshots.isEmpty {
                Text("No usage signal")
                    .font(.headline)
                    .padding()
            } else {
                ForEach(viewModel.snapshots, id: \.id) { snapshot in
                    StatusCardView(snapshot: snapshot)
                }
            }
        }
        .padding()
    }
}
```

Create `apps/mac/Sources/WhatTheTokenMac/WhatTheTokenApp.swift`:

```swift
import SwiftUI

@main
struct WhatTheTokenApp: App {
    var body: some Scene {
        WindowGroup {
            AppModel(viewModel: .fixture())
        }
    }
}
```

- [x] **Step 7: Run Swift tests**

Run:

```bash
cd apps/mac
swift test
```

Expected: PASS.

- [x] **Step 8: Build Swift app**

Run:

```bash
cd apps/mac
swift build
```

Expected: PASS on macOS with Swift 6 toolchain. If the local toolchain is older, lower `swift-tools-version` only after confirming available Swift version with `swift --version`.

- [x] **Step 9: Commit**

```bash
git add apps/mac
git commit -m "feat(mac): render fixture usage status"
```

## Task 5A: Mac Status Card Display And Fixture Safety Tests

**Status:** Completed in `4ca44ff` (`test(mac): cover fixture card display`) and hardened in `39a6408` (`test(mac): scan fixture keys recursively`).

**Verification:**
- `cd apps/mac && swift test` passed with 5 Swift Testing tests.
- `cd apps/mac && swift build` passed.
- `pnpm check` passed with 4 core test files and 13 core tests.

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusCardDisplayModel.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/StatusCardView.swift`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/StatusCardDisplayModelTests.swift`

**Purpose:** Close the Task 5 review gaps by testing the user-visible card strings and making the fixture safety assertion explicit.

- [x] **Step 1: Write failing display model tests**

Create `apps/mac/Tests/WhatTheTokenMacTests/StatusCardDisplayModelTests.swift`:

```swift
import Testing
@testable import WhatTheTokenMac

@Test func formatsFixtureBackedStatusCardStrings() throws {
    let snapshot = try StatusViewModel.loadFixtureSnapshot()
    let display = StatusCardDisplayModel(snapshot: snapshot)

    #expect(display.title == "Anthropic / claude code")
    #expect(display.primaryMetric == "38% remaining")
    #expect(display.confidenceLabel == "Verified")
    #expect(display.updatedLabel == "Updated 2026-05-04T10:00:00.000Z")
    #expect(display.progressValue == 0.62)
}

@Test func formatsObservedUsageWhenRemainingIsUnknown() {
    let snapshot = UsageSnapshot(
        id: "snap_observed",
        userAccountId: "fixture_user",
        provider: "openai",
        product: "codex",
        surface: "cli",
        poolKey: "openai_codex",
        windowKey: "daily",
        unit: "requests",
        used: nil,
        limit: nil,
        remaining: nil,
        utilization: nil,
        resetAt: nil,
        lastUpdatedAt: "2026-05-04T10:00:00.000Z",
        confidence: "observed",
        undercountRisk: "possible",
        staleReason: nil
    )

    let display = StatusCardDisplayModel(snapshot: snapshot)

    #expect(display.title == "Openai / codex")
    #expect(display.primaryMetric == "Usage observed")
    #expect(display.confidenceLabel == "Observed")
    #expect(display.updatedLabel == "Updated 2026-05-04T10:00:00.000Z")
    #expect(display.progressValue == 0)
}
```

Run:

```bash
cd apps/mac
swift test
```

Expected: FAIL because `StatusCardDisplayModel` does not exist.

- [x] **Step 2: Add display model**

Create `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusCardDisplayModel.swift`:

```swift
import Foundation

struct StatusCardDisplayModel: Equatable, Sendable {
    let title: String
    let primaryMetric: String
    let confidenceLabel: String
    let updatedLabel: String
    let progressValue: Double

    init(snapshot: UsageSnapshot) {
        title = "\(snapshot.provider.capitalized) / \(snapshot.product.replacingOccurrences(of: "_", with: " "))"
        confidenceLabel = snapshot.confidence.capitalized
        updatedLabel = "Updated \(snapshot.lastUpdatedAt)"
        progressValue = snapshot.utilization ?? 0
        primaryMetric = Self.primaryMetric(for: snapshot)
    }

    private static func primaryMetric(for snapshot: UsageSnapshot) -> String {
        guard let remaining = snapshot.remaining else {
            return "Usage observed"
        }

        switch snapshot.unit {
        case "utilization":
            return "\(Int(remaining))% remaining"
        case "credits":
            return "\(remaining.formatted()) credits remaining"
        case "tokens":
            return "\(Int(remaining)) tokens remaining"
        case "requests":
            return "\(Int(remaining)) requests remaining"
        case "messages":
            return "\(Int(remaining)) messages remaining"
        default:
            return "\(remaining.formatted()) remaining"
        }
    }
}
```

- [x] **Step 3: Use display model in the SwiftUI card**

Replace `apps/mac/Sources/WhatTheTokenMac/Views/StatusCardView.swift` with:

```swift
import SwiftUI

struct StatusCardView: View {
    private let display: StatusCardDisplayModel

    init(snapshot: UsageSnapshot) {
        display = StatusCardDisplayModel(snapshot: snapshot)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(display.title)
                    .font(.headline)
                Spacer()
                Text(display.confidenceLabel)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Text(display.primaryMetric)
                .font(.system(size: 28, weight: .semibold))

            ProgressView(value: display.progressValue)
                .progressViewStyle(.linear)

            Text(display.updatedLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 320, alignment: .leading)
    }
}
```

- [x] **Step 4: Expose fixture data loading through the view model**

Replace `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift` with:

```swift
import Foundation
import Observation

@Observable
final class StatusViewModel {
    var snapshots: [UsageSnapshot]

    init(snapshots: [UsageSnapshot] = []) {
        self.snapshots = snapshots
    }

    static func loadFixtureData() throws -> Data {
        guard let url = Bundle.module.url(forResource: "usage-snapshot.fixture", withExtension: "json") else {
            throw FixtureError.missingFixture
        }

        return try Data(contentsOf: url)
    }

    static func loadFixtureSnapshot() throws -> UsageSnapshot {
        let data = try loadFixtureData()
        return try JSONDecoder().decode(UsageSnapshot.self, from: data)
    }

    static func fixture() -> StatusViewModel {
        do {
            return StatusViewModel(snapshots: [try loadFixtureSnapshot()])
        } catch {
            return StatusViewModel(snapshots: [])
        }
    }
}

enum FixtureError: Error {
    case missingFixture
}
```

- [x] **Step 5: Rename fixture decoding test and add explicit safety scan**

Replace `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift` with:

```swift
import Foundation
import Testing
@testable import WhatTheTokenMac

@Test func loadsFixtureSnapshot() throws {
    let snapshot = try StatusViewModel.loadFixtureSnapshot()

    #expect(snapshot.product == "claude_code")
    #expect(snapshot.confidence == "verified")
    #expect(snapshot.remaining == 38)
    #expect(snapshot.staleReason == nil)
}

@Test func fixtureJSONDoesNotContainSensitiveKeys() throws {
    let data = try StatusViewModel.loadFixtureData()
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let disallowedKeys = [
        "prompt",
        "completion",
        "conversation",
        "conversationUrl",
        "cookie",
        "authHeader",
        "bearerToken",
        "sessionToken"
    ]

    #expect(sensitiveKeyMatches(in: object, disallowedKeys: disallowedKeys).isEmpty)
}

@Test func sensitiveKeyScanFindsNestedMatches() {
    let object: [String: Any] = [
        "provider": "anthropic",
        "metadata": [
            "conversation": "should not be collected",
            "usage": [
                ["remaining": 38],
                ["sessionToken": "should not be collected"]
            ]
        ]
    ]

    #expect(sensitiveKeyMatches(in: object, disallowedKeys: ["conversation", "sessionToken"]) == [
        "metadata.conversation",
        "metadata.usage[1].sessionToken"
    ])
}

private func sensitiveKeyMatches(
    in value: Any,
    disallowedKeys: [String],
    path: String = ""
) -> [String] {
    if let dictionary = value as? [String: Any] {
        return dictionary.keys.sorted().flatMap { key -> [String] in
            let childPath = path.isEmpty ? key : "\(path).\(key)"
            let currentMatch = disallowedKeys.contains(key) ? [childPath] : []
            return currentMatch + sensitiveKeyMatches(
                in: dictionary[key] as Any,
                disallowedKeys: disallowedKeys,
                path: childPath
            )
        }
    }

    if let array = value as? [Any] {
        return array.indices.flatMap { index in
            sensitiveKeyMatches(
                in: array[index],
                disallowedKeys: disallowedKeys,
                path: "\(path)[\(index)]"
            )
        }
    }

    return []
}
```

- [x] **Step 6: Run Swift tests**

Run:

```bash
cd apps/mac
swift test
```

Expected: PASS with five Swift tests covering fixture decoding, recursive fixture safety scanning, nested sensitive-key scan regression coverage, and display model formatting.

- [x] **Step 7: Build Swift app**

Run:

```bash
cd apps/mac
swift build
```

Expected: PASS.

- [x] **Step 8: Commit**

```bash
git add apps/mac
git commit -m "test(mac): cover fixture card display"
```

## Task 6: Mac Fixture Contract Test

**Status:** Complete in `98dfc24` (`test(core): validate Mac fixture contract`) and reverified on 2026-05-04.

**Verification evidence:**
- `pnpm check` passed with the Mac fixture contract test included.
- `cd apps/mac && swift test` passed with 5 Swift tests.
- `cd apps/mac && swift build` passed.

**Files:**
- Test: `packages/core/src/__tests__/mac-fixture-contract.test.ts`
- Modify: `apps/mac/Sources/WhatTheTokenMac/Resources/usage-snapshot.fixture.json`

- [ ] **Step 1: Write failing contract test**

Create `packages/core/src/__tests__/mac-fixture-contract.test.ts`:

```ts
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { usageSnapshotSchema } from "../schemas";

describe("Mac fixture contract", () => {
  it("keeps the SwiftUI fixture valid against the shared snapshot schema", () => {
    const testDir = dirname(fileURLToPath(import.meta.url));
    const fixturePath = resolve(
      testDir,
      "../../../../apps/mac/Sources/WhatTheTokenMac/Resources/usage-snapshot.fixture.json"
    );

    const fixture = JSON.parse(readFileSync(fixturePath, "utf8"));
    const parsed = usageSnapshotSchema.parse(fixture);

    expect(parsed.product).toBe("claude_code");
    expect(parsed.poolKey).toBe("anthropic_claude_subscription");
  });
});
```

- [ ] **Step 2: Run test to verify contract**

Run:

```bash
pnpm --filter @whatthetoken/core test -- mac-fixture-contract.test.ts
```

Expected: PASS. If this fails, fix the Swift fixture JSON or shared schema before continuing.

- [ ] **Step 3: Run all core tests**

Run:

```bash
pnpm --filter @whatthetoken/core test
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add packages/core/src/__tests__/mac-fixture-contract.test.ts apps/mac/Sources/WhatTheTokenMac/Resources/usage-snapshot.fixture.json
git commit -m "test(core): validate Mac fixture contract"
```

## Task 7: Privacy And Contract Documentation

**Status:** Complete in `3d8e7d9` (`docs: define data and privacy boundaries`) and expanded through the dedicated Task 7 plan in `5eb1d3b` and `5174627`.

**Verification evidence:**
- `docs/superpowers/specs/2026-05-04-task-7-privacy-contract-documentation-design.md` defines the documentation requirements.
- `docs/superpowers/plans/2026-05-04-task-7-privacy-contract-documentation.md` defines the dedicated implementation plan.
- `docs/architecture/data-contract.md`, `docs/architecture/privacy-boundaries.md`, `docs/architecture/tech-stack-and-development-approach.md`, and `docs/agent/operating-rules.md` are present and linked.

**Files:**
- Create: `docs/architecture/data-contract.md`
- Create: `docs/architecture/privacy-boundaries.md`
- Modify: `docs/architecture/tech-stack-and-development-approach.md`

- [ ] **Step 1: Write data contract doc**

Create `docs/architecture/data-contract.md`:

```md
# Data Contract

The product uses provider/product/surface as separate fields.

Every usage snapshot must include:

- provider
- product
- surface
- poolKey
- windowKey
- unit
- confidence
- freshness
- undercount risk

Allowed units:

- messages
- requests
- tokens
- credits
- utilization

The shared TypeScript schemas in `packages/core/src/schemas.ts` are the source of truth for event and snapshot shape during Phase 1.
```

- [ ] **Step 2: Write privacy boundaries doc**

Create `docs/architecture/privacy-boundaries.md`:

```md
# Privacy Boundaries

WhatTheToken must never collect:

- prompts
- completions
- conversation content
- conversation URLs
- cookies
- auth headers
- bearer tokens
- provider session tokens
- browser request bodies

Allowed usage data:

- provider
- product
- surface
- model key when detectable
- event type
- count, utilization, request, token, or credit amount
- observed timestamp
- device identifier
- confidence level
- source/parser version
- sync/error status

Any future change to these boundaries requires an ADR.
```

- [ ] **Step 3: Run documentation grep**

Run:

```bash
rg -n "prompt|completion|cookie|token|auth header|session" docs packages apps
```

Expected: Any matches are in privacy rules, tests that reject sensitive fields, or source references. There should be no fixture containing real prompt/response/session content.

- [ ] **Step 4: Commit**

```bash
git add docs/architecture
git commit -m "docs: define data and privacy boundaries"
```

## Task 8: Codex CLI Local Signal Feasibility Spike

**Status:** Complete in `b45d08f` (`docs: record Codex CLI signal spike`).

**Finding:** Local Codex paths likely contain useful metadata, but the next safe Codex step requires explicit redaction review before reading contents.

**Files:**
- Create: `docs/research/codex-cli-local-signal-spike.md`

- [ ] **Step 1: Create research directory**

Run:

```bash
mkdir -p docs/research
```

Expected: directory exists.

- [ ] **Step 2: Check whether Codex CLI is installed**

Run:

```bash
if command -v codex >/dev/null 2>&1; then
  command -v codex
  codex --version
  codex --help
else
  echo "codex CLI not installed"
fi
```

Expected: command output identifies whether Codex CLI exists locally. Absence is an acceptable finding. Do not paste auth tokens, prompts, logs, or session contents into docs.

- [ ] **Step 3: Inspect non-sensitive Codex local metadata locations**

Run these only if the paths exist:

```bash
if [ -d "$HOME/.codex" ]; then
  ls -la "$HOME/.codex"
  find "$HOME/.codex" -maxdepth 2 -type f \( -name "*.json" -o -name "*.toml" -o -name "*.yaml" -o -name "*.yml" -o -name "*.sqlite" -o -name "*.db" \)
else
  echo "~/.codex does not exist"
fi
```

Expected: identify candidate config or usage metadata files. Do not print file contents yet unless the filename and purpose are clearly non-sensitive. If unsure, record the filename only.

- [ ] **Step 4: Write findings**

Create `docs/research/codex-cli-local-signal-spike.md`:

```md
# Codex CLI Local Signal Spike

Date: 2026-05-04

## Goal

Determine whether WhatTheToken can observe useful Codex CLI consumption signals locally without collecting prompts, responses, cookies, bearer tokens, auth headers, or provider session tokens.

## Commands Run

- `which codex`
- `codex --version`
- `codex --help`
- `ls -la ~/.codex`
- `find ~/.codex -maxdepth 2 -type f \( ... \)`

## Findings

Record:

- Whether Codex CLI is installed.
- Version.
- Relevant subcommands.
- Candidate local metadata files by path only.
- Whether any candidate appears safe to parse.

## Sensitive Data Review

Record whether any inspected path appears likely to contain:

- prompts
- responses
- auth credentials
- session tokens
- conversation content

Do not copy sensitive contents into this document.

## Recommendation

Choose one:

- Safe to implement local Codex observer next.
- Needs manual user permission and redaction review.
- Not viable locally; use another surface first.
```

- [ ] **Step 5: Commit**

```bash
git add docs/research/codex-cli-local-signal-spike.md
git commit -m "docs: record Codex CLI signal spike"
```

## Task 9: Claude Code Local Signal Feasibility Spike

**Status:** Complete in `8b421de` (`docs: record Claude Code signal spike`).

**Finding:** Claude Code is installed and the `Claude Code-credentials` Keychain item exists, but the CLI exposes no safe quota/status command. `~/.claude/policy-limits.json` is the most promising local filename and still needs narrow redaction review before implementation uses it.

**Files:**
- Create: `docs/research/claude-code-local-signal-spike.md`

- [ ] **Step 1: Check whether Claude Code is installed**

Run:

```bash
if command -v claude >/dev/null 2>&1; then
  command -v claude
  claude --version
  claude --help
else
  echo "Claude Code CLI not installed"
fi
```

Expected: command output identifies whether Claude Code exists locally. Absence is an acceptable finding.

- [ ] **Step 2: Check non-secret credential presence without reading values**

Run:

```bash
security find-generic-password -s "Claude Code-credentials"
```

Expected: command may show metadata or may fail if the Keychain item is absent. Do not run `security find-generic-password -g`; that can print secret material.

- [ ] **Step 3: Inspect non-sensitive Claude local metadata locations**

Run these only if the paths exist:

```bash
if [ -d "$HOME/.claude" ]; then
  ls -la "$HOME/.claude"
  find "$HOME/.claude" -maxdepth 2 -type f \( -name "*.json" -o -name "*.toml" -o -name "*.yaml" -o -name "*.yml" -o -name "*.sqlite" -o -name "*.db" \)
else
  echo "~/.claude does not exist"
fi
```

Expected: identify candidate config or usage metadata files. Do not print file contents yet unless the filename and purpose are clearly non-sensitive. If unsure, record the filename only.

- [ ] **Step 4: Write findings**

Create `docs/research/claude-code-local-signal-spike.md`:

```md
# Claude Code Local Signal Spike

Date: 2026-05-04

## Goal

Determine whether WhatTheToken can observe useful Claude Code subscription or usage signals locally without collecting prompts, responses, cookies, bearer tokens, auth headers, provider session tokens, or Keychain secret values.

## Commands Run

- `which claude`
- `claude --version`
- `claude --help`
- `security find-generic-password -s "Claude Code-credentials"`
- `ls -la ~/.claude`
- `find ~/.claude -maxdepth 2 -type f \( ... \)`

## Findings

Record:

- Whether Claude Code is installed.
- Version.
- Relevant subcommands.
- Whether the Keychain item exists.
- Candidate local metadata files by path only.
- Whether Claude Code exposes a safe status command.

## Sensitive Data Review

Record whether any inspected path appears likely to contain:

- prompts
- responses
- auth credentials
- session tokens
- conversation content
- Keychain secret values

Do not copy sensitive contents into this document.

## Recommendation

Choose one:

- Safe to implement Claude Code usage poller next.
- Needs manual user permission and redaction review.
- Not viable locally; use another surface first.
```

- [ ] **Step 5: Commit**

```bash
git add docs/research/claude-code-local-signal-spike.md
git commit -m "docs: record Claude Code signal spike"
```

## Task 10: Full Phase 1 Verification

**Status:** Verified on 2026-05-04 after rebasing onto `origin/main`.

**Verification evidence:**
- `pnpm check` passed.
- `cd apps/mac && swift test` passed with 5 Swift tests.
- `cd apps/mac && swift build` passed.
- `rg -n "prompt|completion|cookie|bearer|auth header|session token|conversation" packages apps docs` was reviewed. Matches are privacy rules, research notes, roadmap/spec text, or tests that intentionally reject sensitive fields; no fixture or app resource contains real sensitive provider data.
- `git status --short` was clean before this plan update.

**Files:**
- No new files.

- [ ] **Step 1: Run TypeScript checks**

Run:

```bash
pnpm check
```

Expected: PASS.

- [ ] **Step 2: Run Swift checks**

Run:

```bash
cd apps/mac
swift test
swift build
```

Expected: PASS.

- [ ] **Step 3: Run privacy grep**

Run:

```bash
rg -n "prompt|completion|cookie|bearer|auth header|session token|conversation" packages apps
```

Expected: No matches except test strings that intentionally verify sensitive fields are rejected.

- [ ] **Step 4: Review working tree**

Run:

```bash
git status --short
```

Expected: clean working tree after commits, or only intentional uncommitted planning docs if commits were skipped by instruction.

## Phase 1 Completion Criteria

Phase 1 is complete when:

- `packages/core` has schema, stale detection, and snapshot derivation tests passing.
- The SwiftUI Mac app compiles and renders one fixture-backed usage card.
- Codex CLI and Claude Code feasibility spikes are documented.
- The fixture contains no sensitive user data.
- The tech stack and development approach doc exists.
- Privacy boundaries are documented.
- The implementation still excludes Supabase, web dashboard, browser extension, iOS, payments, and production analytics.

## Claude Code Implementation Readiness

The dedicated Claude Code local connector spec and implementation plan now exist:

- `docs/superpowers/specs/2026-05-04-local-connector-trust-design.md`
- `docs/superpowers/plans/2026-05-04-local-connector-trust.md`

The implementation is present in `apps/mac/Sources/WhatTheTokenMac/Claude`, `apps/mac/Sources/WhatTheTokenMac/Connectors`, and the connector-source additions in `packages/core`.

Pending before live local testing:

- A developer-only smoke harness now exists behind the explicit `--claude-connector-smoke` flag and invokes `ClaudeConnectorService` with `ClaudeConnectorSettings(isEnabled: true)`.
- The first live smoke was run locally on 2026-05-04 with `CLAUDE_CODE_VERSION=2.1.126`. It returned four sanitized snapshot summary lines and did not print tokens, authorization headers, or raw provider JSON. Automated tests must continue using fixtures and mocks, not a real Keychain credential or live Anthropic response.
- Product wiring now uses an explicit `Connect Claude Code` path. App startup injects connector dependencies but does not refresh Claude, run the CLI version command, read Keychain credentials, or call Anthropic until the user connects.
- Follow-up hardening added restricted-path Claude executable resolution, duplicate-connect protection, tested setup copy, and a bounded local GUI launch smoke on 2026-05-05.
- Do not inspect `~/.claude/policy-limits.json` for this connector slice. The implemented path uses the Claude Code Keychain credential and Anthropic OAuth usage endpoint; local metadata inspection remains a separate Codex/Claude research task.
