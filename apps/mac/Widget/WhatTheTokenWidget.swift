import SwiftUI
import WidgetKit

@main
struct WhatTheTokenWidgetBundle: WidgetBundle {
    var body: some Widget {
        WhatTheTokenWidget()
    }
}

struct WhatTheTokenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WhatTheTokenWidget", provider: WidgetTimelineProvider()) { entry in
            WidgetSmallView(entry: entry)
        }
        .configurationDisplayName("WhatTheToken")
        .description("Live quota status for connected providers.")
        .supportedFamilies([.systemSmall])
    }
}
