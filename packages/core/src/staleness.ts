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
