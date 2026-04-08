import SwiftUI

struct CompactMetricView: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
    }
}
