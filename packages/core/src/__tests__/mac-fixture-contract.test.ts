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
