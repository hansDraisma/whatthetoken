import Foundation
import WidgetKit

struct WidgetTimelineProvider: TimelineProvider {
    typealias Entry = WidgetTimelineEntry

    func placeholder(in context: Context) -> WidgetTimelineEntry {
        WidgetTimelineEntry(date: Date(), payload: SnapshotEntryBuilder.placeholder())
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetTimelineEntry) -> Void) {
        completion(currentEntry(now: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetTimelineEntry>) -> Void) {
        let entry = currentEntry(now: Date())
        let nextReload = Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextReload)))
    }

    private func currentEntry(now: Date) -> WidgetTimelineEntry {
        let payload: WidgetEntry
        if let url = sharedSnapshotURL(),
           let data = try? Data(contentsOf: url),
           let snapshot = try? SnapshotCache.decodeValidated(from: data) {
            payload = SnapshotEntryBuilder.entry(from: snapshot, now: now)
        } else {
            payload = SnapshotEntryBuilder.placeholder()
        }
        return WidgetTimelineEntry(date: now, payload: payload)
    }

    private func sharedSnapshotURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.whatthetoken.mac")?
            .appendingPathComponent("snapshot-cache.json")
    }
}

struct WidgetTimelineEntry: TimelineEntry {
    let date: Date
    let payload: WidgetEntry
}
