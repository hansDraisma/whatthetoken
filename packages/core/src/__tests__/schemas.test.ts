import { describe, expect, it } from "vitest";
import { usageEventSchema, usageSnapshotSchema } from "../schemas";

const fixtureSource = {
  connector: "manual_fixture",
  state: "connected",
  label: "Fixture",
  parserVersion: "fixture-v1",
  deviceId: "fixture_device"
} as const;

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
      staleReason: null,
      source: fixtureSource
    });

    expect(parsed.poolKey).toBe("anthropic_claude_subscription");
    expect(parsed.confidence).toBe("verified");
  });

  it("requires sanitized source metadata on snapshots", () => {
    const parsed = usageSnapshotSchema.parse({
      id: "snap_with_source",
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
      staleReason: null,
      source: {
        connector: "mac_connector",
        state: "connected",
        label: "Mac connector",
        parserVersion: "claude-code-oauth-usage-v1",
        deviceId: "device_mac_01"
      }
    });

    expect(parsed.source.connector).toBe("mac_connector");
    expect(parsed.source.parserVersion).toBe("claude-code-oauth-usage-v1");
  });

  it("rejects source metadata that contains credential material", () => {
    expect(() =>
      usageSnapshotSchema.parse({
        id: "snap_with_token",
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
        staleReason: null,
        source: {
          connector: "mac_connector",
          state: "connected",
          label: "Mac connector",
          parserVersion: "claude-code-oauth-usage-v1",
          deviceId: "device_mac_01",
          accessToken: "sk-do-not-allow"
        }
      })
    ).toThrow();
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
        staleReason: null,
        source: fixtureSource
      })
    ).toThrow();
  });

  it("rejects stale snapshots without a stale reason", () => {
    expect(() =>
      usageSnapshotSchema.parse({
        id: "snap_stale_without_reason",
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
        confidence: "stale",
        undercountRisk: "possible",
        staleReason: null,
        source: fixtureSource
      })
    ).toThrow();
  });

  it("rejects non-stale snapshots with a stale reason", () => {
    expect(() =>
      usageSnapshotSchema.parse({
        id: "snap_fresh_with_reason",
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
        staleReason: "Last update was 12 minutes ago.",
        source: fixtureSource
      })
    ).toThrow();
  });
});
