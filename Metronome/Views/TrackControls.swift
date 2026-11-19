import SwiftUI
import UniformTypeIdentifiers

/// The track screen's card at the bottom (6.12), in place of the Start row and the next-up
/// line: the file's name, the progress bar, the transport row and, for a setlist song, the
/// next-up line. Its height is fixed; it never shrinks.
struct PlayerCard: View {
    @Environment(MetronomeModel.self) private var model
    private let showsNextLine: Bool

    init(showsNextLine: Bool) {
        self.showsNextLine = showsNextLine
    }

    private static let transportHeight: CGFloat = 68

    var body: some View {
        VStack(spacing: 12) {
            fileNameRow
            TrackProgressBar()
            transportRow
            if showsNextLine {
                NextUpLine(next: model.nextSong)
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 16)
        .padding(.bottom, 18)
        .frame(
            height: TrackScreenLayout.playerCardHeight + (showsNextLine ? TrackScreenLayout.playerNextLineHeight : 0),
            alignment: .top
        )
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    /// The music note, 8 pt after it the file's name, which takes the space left, and 8 pt
    /// after that one pill: `Sync`, or `Choose file` while the file is missing. The amber name
    /// and the pill say the file is missing, so the card does not.
    private var fileNameRow: some View {
        let isMissing = model.isTrackMissing
        let fileName = model.loadedTrack?.fileName ?? ""
        return HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "music.note")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.muted)
                Text(fileName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isMissing ? Theme.amber : Theme.dialWhite)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isMissing ? "Track missing, \(fileName)" : "Backing track, \(fileName)")
            if isMissing {
                ChooseFilePill()
            } else {
                CardPill(title: "Sync", sidePadding: 14) { model.enterSyncMode() }
            }
        }
        .frame(height: 30)
    }

    /// Five places spread evenly, the outer two at the edges. Outside a setlist the outer two
    /// stay empty, so Rewind, play / stop and Fast-forward keep their places, centred.
    private var transportRow: some View {
        let inSetlist = model.position != nil
        return HStack(spacing: 0) {
            if inSetlist {
                SongStepButton(symbol: "backward.end", label: "Previous song", isEnabled: model.canGoPrevious) {
                    model.goToPrevious()
                }
            } else {
                emptyPlace
            }
            Spacer(minLength: 0)
            TrackSkipButton(isForward: false)
            Spacer(minLength: 0)
            PlayStopCircle()
            Spacer(minLength: 0)
            TrackSkipButton(isForward: true)
            Spacer(minLength: 0)
            if inSetlist {
                SongStepButton(symbol: "forward.end", label: "Next song", isEnabled: model.canGoNext) {
                    model.goToNext()
                }
            } else {
                emptyPlace
            }
        }
        .frame(height: Self.transportHeight)
    }

    private var emptyPlace: some View {
        Color.clear.frame(width: SongStepButton.size, height: SongStepButton.size)
    }
}

/// A pill at the end of the player card's file-name row: fully rounded on surface raised, as
/// tall as the row, with a touch area 44 pt tall.
private struct CardPill: View {
    let title: String
    let sidePadding: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.dialWhite)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, sidePadding)
                .frame(height: 30)
                .background(Theme.surfaceRaised, in: Capsule())
                .contentShape(Rectangle().inset(by: -7))
        }
        .buttonStyle(.plain)
    }
}

/// `Choose file` while the track's file is missing: the Files picker for audio, and the picked
/// file stored at once for the missing track (6.12). While the pick is read the pill does
/// nothing but keeps its look.
private struct ChooseFilePill: View {
    @Environment(MetronomeModel.self) private var model
    @State private var isPickerShown = false
    /// The file being copied and read.
    @State private var pickToRead: URL?
    @State private var isUnplayableShown = false
    @State private var isTrackNotStoredShown = false

    var body: some View {
        CardPill(title: "Choose file", sidePadding: 12) { isPickerShown = true }
            .disabled(pickToRead != nil)
            .fileImporter(isPresented: $isPickerShown, allowedContentTypes: [.audio]) { result in
                switch result {
                case .success(let url):
                    pickToRead = url
                case .failure(let error):
                    // Closing the picker is not a failure to read a file.
                    if (error as? CocoaError)?.code != .userCancelled { isUnplayableShown = true }
                }
            }
            // The pill going away cancels the read; a copy that arrives then is deleted.
            .task(id: pickToRead) {
                guard let url = pickToRead,
                      let result = await PickedFileReader.readInBackground(url) else { return }
                switch result {
                case .success(let picked):
                    if !model.chooseFileForLoadedTrack(picked) { isTrackNotStoredShown = true }
                    // The model keeps its own copy when it stores the file; nothing is kept for
                    // a retry when it cannot, as the pick is made again from the pill.
                    PickedFileReader.discard(picked)
                case .failure:
                    isUnplayableShown = true
                }
                pickToRead = nil
            }
            .alert("This file can't be played", isPresented: $isUnplayableShown) {
                Button("OK", role: .cancel) {}
            }
            .alert("The track couldn't be saved", isPresented: $isTrackNotStoredShown) {
                Button("OK", role: .cancel) {}
            }
    }
}

/// The player card's Start / Stop: a 68 pt circle with a symbol and no word, styled like the
/// Start / Stop pill, with its haptic and rules.
private struct PlayStopCircle: View {
    @Environment(MetronomeModel.self) private var model

    var body: some View {
        let isPlaying = model.isPlaying
        Button {
            model.togglePlayback()
        } label: {
            Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                .font(.system(size: isPlaying ? 22 : 26, weight: .bold))
                .foregroundStyle(isPlaying ? Theme.amber : Theme.ink)
                // The triangle's weight sits left of its frame's centre.
                .offset(x: isPlaying ? 0 : 2)
                .frame(width: 68, height: 68)
                .background(isPlaying ? Theme.surface : Theme.amber, in: Circle())
                .overlay(Circle().strokeBorder(Theme.amber, lineWidth: 1.5).opacity(isPlaying ? 1 : 0))
                .shadow(color: isPlaying ? .clear : Theme.amber.opacity(0.28), radius: 20)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Stop" : "Start")
    }
}

/// Previous song and Next song on the player card: an arrow against a bar with no fill.
/// Dimmed and doing nothing at the ends of the setlist.
private struct SongStepButton: View {
    let symbol: String
    let label: String
    let isEnabled: Bool
    let action: () -> Void

    static let size: CGFloat = 44

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.dialWhite)
                .frame(width: Self.size, height: Self.size)
                .opacity(isEnabled ? 1 : 0.4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }
}

/// The line with its knob, and the times below it. Used on the player card and on
/// Sync mode's playback card. 40 pt tall: a 22 pt band for the line and knob, then the times 2 pt below it.
struct TrackProgressBar: View {
    @Environment(MetronomeModel.self) private var model
    /// The unplayed part of the line: the line colour on surface, surface selected on surface
    /// raised, where the line colour would not show.
    var unplayed: Color = Theme.line
    /// Where the knob has been dragged from and to. Gesture state goes back to nil when the
    /// drag is cancelled as well as when it ends, so the knob never sticks off the position.
    @GestureState private var drag: KnobDrag?
    /// The time the knob was last dragged to, sought when the finger lifts.
    @State private var dropTime: TimeInterval?

    private struct KnobDrag {
        let start: TimeInterval
        var time: TimeInterval
    }

    static let height: CGFloat = 40
    /// The band holding the line and the knob; the line runs along its middle.
    nonisolated static let bandHeight: CGFloat = 22
    private static let knobSize: CGFloat = 14
    private static let lineHeight: CGFloat = 4

    var body: some View {
        // The position is read from the engine and not observed, so it is redrawn while playing.
        // The timeline stays in place, paused while stopped, so a drag survives Start and Stop.
        TimelineView(.animation(minimumInterval: 0.1, paused: !model.isPlaying)) { _ in bar }
    }

    private var bar: some View {
        let isMissing = model.isTrackMissing
        let length = model.trackLength ?? 0
        let isCountingIn = model.isCountingIn
        let shown = drag?.time ?? model.trackTime
        let fraction = length > 0 ? min(max(shown / length, 0), 1) : 0
        return VStack(spacing: 2) {
            GeometryReader { proxy in
                // The knob's centre travels between the line's ends, so it never overhangs them.
                let travel = max(proxy.size.width - Self.knobSize, 1)
                let knobX = Self.knobSize / 2 + travel * fraction
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(unplayed)
                        .frame(height: Self.lineHeight)
                    Capsule()
                        .fill(Theme.amber)
                        .frame(width: knobX, height: Self.lineHeight)
                    Circle()
                        .fill(Theme.dialWhite)
                        .frame(width: Self.knobSize, height: Self.knobSize)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .position(x: knobX, y: Self.bandHeight / 2)
                        .gesture(knobDrag(travel: travel, length: length))
                }
                .frame(height: Self.bandHeight)
            }
            .frame(height: Self.bandHeight)
            HStack {
                if !isMissing {
                    Text(isCountingIn ? "Count-in" : TrackTime.label(shown))
                        .foregroundStyle(isCountingIn ? Theme.amber : Theme.muted)
                    Spacer(minLength: 8)
                    Text(TrackTime.label(length))
                        .foregroundStyle(Theme.muted)
                }
            }
            .font(.system(size: 13).monospacedDigit())
            .lineLimit(1)
            .frame(height: Self.height - Self.bandHeight - 2)
        }
        .frame(height: Self.height)
        .opacity(isMissing ? 0.4 : 1)
        .allowsHitTesting(!isMissing)
        .accessibilityElement(children: .ignore)
        .accessibilityValue(
            isCountingIn ? "Count-in" : "\(TrackTime.spoken(shown)) of \(TrackTime.spoken(length))"
        )
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: model.skipTrack(by: TrackSkipButton.skip)
            case .decrement: model.skipTrack(by: -TrackSkipButton.skip)
            @unknown default: break
            }
        }
        // It would read "0 seconds of 0 seconds"; the file-name row already reads "Track missing".
        .accessibilityHidden(isMissing)
    }

    /// The knob and the elapsed time follow the finger; the position changes on lift.
    private func knobDrag(travel: CGFloat, length: TimeInterval) -> some Gesture {
        func time(from start: TimeInterval, moved: CGFloat) -> TimeInterval {
            min(max(start + Double(moved / travel) * length, 0), length)
        }
        return DragGesture(minimumDistance: 1)
            .updating($drag) { value, state, _ in
                let start = state?.start ?? model.trackTime
                state = KnobDrag(start: start, time: time(from: start, moved: value.translation.width))
            }
            .onChanged { value in
                let start = drag?.start ?? model.trackTime
                dropTime = time(from: start, moved: value.translation.width)
            }
            .onEnded { _ in
                if let dropTime { model.seekTrack(to: dropTime) }
                dropTime = nil
            }
    }
}

/// Rewind and Fast-forward: 44 pt round with a double chevron, 15 seconds back or forward. On
/// surface raised on the player card, and on surface selected on Sync mode's playback card.
/// Fast-forward is dimmed within the last 15 seconds; both are dimmed, do nothing and are
/// hidden from VoiceOver while the file is missing.
struct TrackSkipButton: View {
    @Environment(MetronomeModel.self) private var model
    let isForward: Bool
    var fill: Color = Theme.surfaceRaised

    static let skip: TimeInterval = 15

    var body: some View {
        if isForward {
            // Whether 15 seconds are left is read from the engine and not observed, so it is
            // read again while playing.
            TimelineView(.animation(minimumInterval: 0.1, paused: !model.isPlaying)) { _ in button }
        } else {
            button
        }
    }

    private var button: some View {
        let isMissing = model.isTrackMissing
        let isEnabled = !isMissing && (!isForward || model.canSkipForward)
        return Button {
            model.skipTrack(by: isForward ? Self.skip : -Self.skip)
        } label: {
            Image(systemName: isForward ? "chevron.forward.2" : "chevron.backward.2")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.dialWhite)
                .frame(width: 44, height: 44)
                .background(fill, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
        .disabled(!isEnabled)
        .accessibilityLabel(isForward ? "Forward 15 seconds" : "Back 15 seconds")
        .accessibilityHidden(isMissing)
    }
}
