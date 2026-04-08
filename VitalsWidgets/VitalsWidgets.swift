import SwiftUI
import WidgetKit

@main
struct VitalsWidgetBundle: WidgetBundle {
    var body: some Widget {
        SingleMetricWidget()
        DualMetricWidget()
        QuadMetricWidget()
    }
}
