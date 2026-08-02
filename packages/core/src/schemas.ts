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
export const connectorSchema = z.enum([
  "mac_connector",
  "chrome_extension",
  "web_dashboard",
  "manual_fixture"
]);
export const connectorStateSchema = z.enum([
  "connected",
  "not_connected",
  "missing_credentials",
  "permission_denied",
  "token_invalid",
  "session_expired",
  "rate_limited",
  "network_error",
  "schema_changed",
  "stale"
]);

export const snapshotSourceSchema = z
  .object({
    connector: connectorSchema,
    state: connectorStateSchema,
    label: z.string().min(1),
    parserVersion: z.string().min(1),
    deviceId: z.string().min(1)
  })
  .strict();

export const snapshotDisplaySchema = z
  .object({
    poolLabel: z.string().min(1).optional(),
    windowLabel: z.string().min(1).optional()
  })
  .strict();

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
    resetAt: z.string().datetime({ offset: true }).nullable(),
    lastUpdatedAt: z.string().datetime(),
    confidence: confidenceSchema,
    undercountRisk: undercountRiskSchema,
    staleReason: z.string().min(1).nullable(),
    display: snapshotDisplaySchema.optional(),
    source: snapshotSourceSchema
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

    const isCreditsBalance =
      snapshot.unit === "credits" && snapshot.used === null && snapshot.limit === null;

    if (
      (snapshot.used === null || snapshot.limit === null) &&
      snapshot.remaining !== null &&
      !isCreditsBalance
    ) {
      context.addIssue({
        code: "custom",
        path: ["remaining"],
        message: "remaining must be null when used or limit is unknown unless unit is credits"
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

export const cachedProviderErrorSchema = z
  .object({
    code: z.enum([
      "network",
      "schemaChanged",
      "unavailable",
      "sessionExpired",
      "missingCredentials",
      "permissionDenied",
      "tokenInvalid",
      "missingClaudeCLI",
      "rateLimited"
    ]),
    message: z.string().min(1),
    consecutiveFailureCount: z.number().int().positive(),
    nextAutomaticRefreshAt: z.string().datetime()
  })
  .strict();

const persistedUsageSnapshotSchema = z.preprocess((input) => {
  if (typeof input !== "object" || input === null || Array.isArray(input)) return input;
  const snapshot = { ...input } as Record<string, unknown>;
  for (const key of ["used", "limit", "remaining", "utilization", "resetAt", "staleReason"]) {
    if (!(key in snapshot)) snapshot[key] = null;
  }
  return snapshot;
}, usageSnapshotSchema);

export const snapshotCacheSchema = z
  .object({
    schemaVersion: z.literal(1),
    snapshots: z.array(persistedUsageSnapshotSchema),
    updatedAtByProvider: z.record(z.string(), z.string().datetime()),
    lastSuccessfulRefreshAtByProvider: z.record(z.string(), z.string().datetime()),
    lastErrorByProvider: z.record(z.string(), cachedProviderErrorSchema)
  })
  .strict();

export type UsageEvent = z.infer<typeof usageEventSchema>;
export type UsageSnapshot = z.infer<typeof usageSnapshotSchema>;
export type SnapshotCache = z.infer<typeof snapshotCacheSchema>;
