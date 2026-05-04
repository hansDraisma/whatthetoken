import Foundation
import Observation

@Observable
final class StatusViewModel {
    var snapshots: [UsageSnapshot]

    init(snapshots: [UsageSnapshot] = []) {
        self.snapshots = snapshots
    }

    static func loadFixtureSnapshot() throws -> UsageSnapshot {
        guard let url = Bundle.module.url(forResource: "usage-snapshot.fixture", withExtension: "json") else {
            throw FixtureError.missingFixture
        }

        let data = try Data(contentsOf: url)
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
