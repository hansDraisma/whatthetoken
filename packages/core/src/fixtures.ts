import { createSnapshotFromQuotaPoll } from "./snapshots";

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
