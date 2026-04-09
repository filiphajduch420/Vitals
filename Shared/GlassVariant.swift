import Foundation

enum GlassVariant: Int, CaseIterable, Codable, Sendable, Identifiable {
    case a = 11
    case b = 0
    case c = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .a: return "A"
        case .b: return "B"
        case .c: return "C"
        }
    }

    static let `default`: GlassVariant = .a
}
