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
    count: z.number().nonnegative(),
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

    if (snapshot.confidence === "stale" && snapshot.staleReason === null) {
      context.addIssue({
        code: "custom",
        path: ["staleReason"],
        message: "staleReason is required when confidence is stale"
      });
    }

    if (snapshot.confidence !== "stale" && snapshot.staleReason !== null) {
      context.addIssue({
        code: "custom",
        path: ["staleReason"],
        message: "staleReason must be null unless confidence is stale"
      });
    }
  });

export type UsageEvent = z.infer<typeof usageEventSchema>;
export type UsageSnapshot = z.infer<typeof usageSnapshotSchema>;
