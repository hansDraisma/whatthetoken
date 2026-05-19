import SwiftUI

struct WidgetSmallView: View {
    let entry: WidgetTimelineEntry

    var body: some View {
        WidgetPreviewView(payload: entry.payload)
            .containerBackground(.fill.tertiary, for: .widget)
    }
}
