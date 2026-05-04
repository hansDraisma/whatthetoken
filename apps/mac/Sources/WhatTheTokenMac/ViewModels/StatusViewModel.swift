import Foundation
import Observation

@Observable
final class StatusViewModel {
    var snapshots: [UsageSnapshot]

    init(snapshots: [UsageSnapshot] = []) {
        self.snapshots = snapshots
    }

    static func loadFixtureData() throws -> Data {
        guard let url = Bundle.module.url(forResource: "usage-snapshot.fixture", withExtension: "json") else {
            throw FixtureError.missingFixture
        }

        return try Data(contentsOf: url)
    }

    static func loadFixtureSnapshot() throws -> UsageSnapshot {
        let data = try loadFixtureData()
        return try JSONDecoder().decode(UsageSnapshot.self, from: data)
    }

    static func fixture() -> StatusViewModel {
        do {
            return StatusViewModel(snapshots: [try loadFixtureSnapshot()])
        } catch {
            return StatusViewModel(snapshots: [])
        }
    }
}

enum FixtureError: Error {
    case missingFixture
}
