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
