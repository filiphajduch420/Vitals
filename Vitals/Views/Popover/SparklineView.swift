import SwiftUI
import Charts

struct SparklineView: View {
    let history: MetricHistory
    var color: Color = .accentColor

    var body: some View {
        Chart(history.values) { snapshot in
            AreaMark(
                x: .value("Time", snapshot.timestamp),
                y: .value("Value", snapshot.value)
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [color.opacity(0.35), color.opacity(0.08), color.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("Time", snapshot.timestamp),
                y: .value("Value", snapshot.value)
            )
            .foregroundStyle(color.opacity(0.9))
            .lineStyle(StrokeStyle(lineWidth: 1.2))
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...1)
        .chartPlotStyle { plotArea in
            plotArea
                .background(color.opacity(0.04))
                .cornerRadius(6)
        }
    }
}
