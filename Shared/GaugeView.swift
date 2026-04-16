import SwiftUI

struct GaugeView: View {
    let value: Double       // 0.0 – 1.0
    var lineWidth: CGFloat = 6
    var size: CGFloat = 44
    var color: Color = .accentColor

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)

            // Value ring
            Circle()
                .trim(from: 0, to: CGFloat(min(value, 1.0)))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.15), value: value)

            // Center label
            Text("\(Int(value * 100))")
                .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(width: size, height: size)
    }
}
