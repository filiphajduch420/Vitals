import SwiftUI
import WidgetKit

@main
struct VitalsWidgetBundle: WidgetBundle {
    var body: some Widget {
        StorageWidget()
        BatteryWidget()
        SystemInfoWidget()
    }
}
