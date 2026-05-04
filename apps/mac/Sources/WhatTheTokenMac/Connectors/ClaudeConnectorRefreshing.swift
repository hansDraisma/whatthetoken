protocol ClaudeConnectorRefreshing: Sendable {
    func refresh() async throws -> ClaudeConnectorResult
}

extension ClaudeConnectorService: ClaudeConnectorRefreshing {}
