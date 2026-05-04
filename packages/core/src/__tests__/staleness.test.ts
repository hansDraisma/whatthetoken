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
