import SwiftUI
import WidgetKit

// MARK: - Donut Ring

struct DonutRing: View {
    let ratio: Double
    let color: Color
    var lineWidth: CGFloat = 10
    var trackOpacity: Double = 0.18
    var glowOpacity: Double = 0.5

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(trackOpacity), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0.001, min(ratio, 1)))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            color.opacity(0.65),
                            color,
                            color.opacity(0.9)
                        ]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(glowOpacity), radius: 3, y: 0)
        }
        .padding(lineWidth / 2)
    }
}

// MARK: - Container background

struct WidgetGradientBackground: View {
    let accentColor: Color
    var accentIntensity: Double = 0.22

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.55),
                    Color.black.opacity(0.75)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    accentColor.opacity(accentIntensity),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 180
            )
        }
    }
}

// MARK: - Header

struct WidgetHeader: View {
    let icon: String
    let title: String
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .kerning(0.6)
            Spacer()
        }
        .foregroundStyle(tint)
    }
}

// MARK: - Stat row (label + value)

struct WidgetStatRow: View {
    let label: String
    let value: String
    var labelWidth: CGFloat = 38
    var valueColor: Color = .primary

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, alignment: .leading)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(valueColor)
        }
    }
}

// MARK: - Big percent display

struct BigPercent: View {
    let percent: Int
    var numberSize: CGFloat = 34
    var symbolSize: CGFloat = 16

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text("\(percent)")
                .font(.system(size: numberSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("%")
                .font(.system(size: symbolSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}
