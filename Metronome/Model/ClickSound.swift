/// The click sounds the user can choose from (specification 11.1), in the order of the settings sheet.
enum ClickSound: String, CaseIterable, Codable, Sendable {
    case digital
    case softBeep
    case woodblock
    case mallet
    case glass
    case tick
    /// Shown as Pendulum. Keeps its earlier name so a saved choice still loads.
    case classic

    static let `default` = ClickSound.digital

    var name: String {
        switch self {
        case .digital: "Digital"
        case .softBeep: "Soft beep"
        case .woodblock: "Woodblock"
        case .mallet: "Mallet"
        case .glass: "Glass"
        case .tick: "Tick"
        case .classic: "Pendulum"
        }
    }
}
