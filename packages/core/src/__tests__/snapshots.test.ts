import { describe, expect, it } from "vitest";
import { createSnapshotFromQuotaPoll } from "../snapshots";

const macConnectorSource = {
  connector: "mac_connector",
  state: "connected",
  label: "Mac connector",
  parserVersion: "test-parser-v1",
  deviceId: "device_mac_01"
} as const;

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
      undercountRisk: "possible",
      source: macConnectorSource
    });

    expect(snapshot.remaining).toBe(38);
    expect(snapshot.utilization).toBe(0.62);
    expect(snapshot.staleReason).toBeNull();
    expect(snapshot.source.connector).toBe("mac_connector");
    expect(snapshot.source.state).toBe("connected");
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
      undercountRisk: "possible",
      source: macConnectorSource
    });

    expect(snapshot.remaining).toBeNull();
    expect(snapshot.utilization).toBeNull();
  });
});
