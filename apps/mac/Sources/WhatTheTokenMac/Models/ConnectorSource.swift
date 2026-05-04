struct ConnectorSource: Codable, Equatable, Sendable {
    let connector: String
    let state: ConnectorSourceState
    let label: String
    let parserVersion: String
    let deviceId: String
}
