import SwiftUI

struct UsageBarView: View {
    let value: Double       // 0.0 – 1.0
    var color: Color = .accentColor
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(color.opacity(0.12))

                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.8), color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * CGFloat(min(value, 1.0)))
                    .animation(.easeInOut(duration: 0.2), value: value)
            }
        }
        .frame(height: height)
    }
}
