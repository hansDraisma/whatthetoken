import type { UsageSnapshot } from "./schemas";
import type { Product, Provider, Surface, UndercountRisk, UsageConfidence, UsageUnit } from "./types";

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

  const utilization = input.used === null || input.limit === null ? null : input.used / input.limit;

  return {
    ...input,
    remaining,
    utilization,
    staleReason: null
  };
}
