import SwiftUI

/// Returns green/yellow/red based on usage ratio (0–1).
func usageColor(_ ratio: Double) -> Color {
    switch ratio {
    case 0..<0.6:  return .green
    case 0.6..<0.8: return .yellow
    default:       return .red
    }
}
