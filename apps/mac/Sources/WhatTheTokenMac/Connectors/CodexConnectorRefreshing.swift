protocol CodexConnectorRefreshing: Sendable {
    func refresh() async throws -> CodexConnectorResult
}

extension CodexConnectorService: CodexConnectorRefreshing {}
