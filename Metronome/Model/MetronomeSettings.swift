/// Everything the user sets: tempo, time signature and accented beats.
struct MetronomeSettings: Codable, Equatable, Sendable {
    private(set) var bpm: Int = Tempo.defaultBPM
    private(set) var timeSignature: TimeSignature = .fourFour
    private(set) var accents: Set<Int> = [1]

    init() {}

    mutating func setBPM(_ bpm: Int) {
        self.bpm = Tempo.clamp(bpm)
    }

    /// Any combination of beats may be accented, including none.
    mutating func toggleAccent(beat: Int) {
        guard (1...timeSignature.beatsPerBar).contains(beat) else { return }
        if accents.contains(beat) {
            accents.remove(beat)
        } else {
            accents.insert(beat)
        }
    }

    /// Returns true when the signature changed. A change resets accents to beat 1.
    @discardableResult
    mutating func setTimeSignature(_ signature: TimeSignature) -> Bool {
        guard signature != timeSignature else { return false }
        timeSignature = signature
        accents = [1]
        return true
    }

    /// Clamps the tempo and drops accents that fall outside the bar.
    func sanitized() -> MetronomeSettings {
        var copy = self
        copy.bpm = Tempo.clamp(bpm)
        copy.accents = accents.filter { (1...timeSignature.beatsPerBar).contains($0) }
        return copy
    }
}
