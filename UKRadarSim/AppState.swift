import Foundation

final class AppState: ObservableObject {
    @Published var vectorSetting: VectorSetting = .off
}

enum VectorSetting: Int, CaseIterable, Identifiable {
    case off = 0
    case sec60 = 60
    case sec120 = 120
    case sec180 = 180

    var id: Int { rawValue }

    var toolbarLabel: String {
        switch self {
        case .off: return "Vectors: Off"
        case .sec60: return "Vectors: 60 sec"
        case .sec120: return "Vectors: 120 sec"
        case .sec180: return "Vectors: 180 sec"
        }
    }

    var menuLabel: String {
        switch self {
        case .off: return "Off"
        case .sec60: return "60 sec"
        case .sec120: return "120 sec"
        case .sec180: return "180 sec"
        }
    }

    var lookaheadSeconds: Double {
        Double(rawValue)
    }
}
