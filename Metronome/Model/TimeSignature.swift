enum TimeSignature: String, CaseIterable, Codable, Sendable {
    case twoFour = "2/4"
    case threeFour = "3/4"
    case fourFour = "4/4"
    case fiveFour = "5/4"
    case sixEight = "6/8"
    case sevenEight = "7/8"
    case nineEight = "9/8"
    case twelveEight = "12/8"

    /// The top number. One beat is one click.
    var beatsPerBar: Int {
        switch self {
        case .twoFour: 2
        case .threeFour: 3
        case .fourFour: 4
        case .fiveFour: 5
        case .sixEight: 6
        case .sevenEight: 7
        case .nineEight: 9
        case .twelveEight: 12
        }
    }

    /// The one-word hint shown under the signature in the picker.
    var hint: String {
        switch self {
        case .twoFour: "March"
        case .threeFour: "Waltz"
        case .fourFour: "Common"
        case .fiveFour, .sevenEight: "Odd"
        case .sixEight, .nineEight, .twelveEight: "Compound"
        }
    }
}
