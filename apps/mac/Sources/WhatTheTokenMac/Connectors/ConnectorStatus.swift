struct ConnectorStatus: Equatable, Sendable {
    let product: String
    let source: ConnectorSource
    let message: String
}
