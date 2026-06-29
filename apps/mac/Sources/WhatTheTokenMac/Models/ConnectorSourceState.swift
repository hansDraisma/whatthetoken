enum ConnectorSourceState: String, Codable, Equatable, Sendable {
    case connected
    case notConnected = "not_connected"
    case missingCredentials = "missing_credentials"
    case permissionDenied = "permission_denied"
    case tokenInvalid = "token_invalid"
    case sessionExpired = "session_expired"
    case rateLimited = "rate_limited"
    case networkError = "network_error"
    case schemaChanged = "schema_changed"
    case stale
}
