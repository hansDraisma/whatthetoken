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

export type Connector = "mac_connector" | "chrome_extension" | "web_dashboard" | "manual_fixture";

export type ConnectorState =
  | "connected"
  | "not_connected"
  | "missing_credentials"
  | "permission_denied"
  | "token_invalid"
  | "rate_limited"
  | "network_error"
  | "schema_changed"
  | "stale";

export type SnapshotSource = {
  connector: Connector;
  state: ConnectorState;
  label: string;
  parserVersion: string;
  deviceId: string;
};
