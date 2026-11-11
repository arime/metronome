<p align="center">
  <img src="site/icon.png" width="128" height="128" alt="Snappy Metronome icon">
</p>

<h1 align="center">Snappy Metronome</h1>

<p align="center">A precise, no-fuss metronome for iPhone.</p>

Set a tempo and a time signature, choose which beats are accented, and press Start. Every beat is a click, a flash on screen and a tap you can feel, all on the same instant. Everything can be changed while it plays.

## Features

- Tempo from 30 to 250 BPM, set with the dial, the − / + buttons or tap tempo
- Eight time signatures: 2/4, 3/4, 4/4, 5/4, 6/8, 7/8, 9/8 and 12/8
- Accent any combination of beats
- Seven click sounds, all generated in code
- Haptics on every beat, with a switch to turn them off
- Presets for your songs, and setlists to step through them in order
- Optional iCloud sync of presets and setlists between your devices
- Plays even when the phone is on silent
- No account, no ads, no tracking

## Support and privacy

- Help and contact: [arime.github.io/metronome](https://arime.github.io/metronome/)
- Privacy policy: [arime.github.io/metronome/privacy.html](https://arime.github.io/metronome/privacy.html). The app collects no data.
- Problems and ideas: email [arime-metronome@proton.me](mailto:arime-metronome@proton.me) or [open an issue](https://github.com/arime/metronome/issues)

## For developers

The app is written in SwiftUI with Swift 6 and has no third-party dependencies. It needs Xcode 26 and runs on iOS 18 or later, on iPhone only.

```sh
scripts/build.sh   # build for the iPhone simulator
scripts/test.sh    # run the unit tests on the iPhone 17 Pro simulator
```

Both scripts print a short summary. The full logs go to `build/build.log` and `build/test.log`.

### Where things are

| Folder | Contents |
|---|---|
| `Metronome/Engine` | Audio scheduling, click synthesis, haptics and the iCloud store |
| `Metronome/Model` | Tempo, time signatures, the beat clock, presets, setlists and sync |
| `Metronome/Views` | The SwiftUI screens and sheets |
| `MetronomeTests` | Unit tests |
| `site` | The support and privacy pages, published to GitHub Pages |

### How it works

[docs/specification.md](docs/specification.md) describes how the app behaves and is kept up to date. It is the place to start. A few points worth knowing:

- **Timing.** Clicks are scheduled ahead of time on the audio clock, never by a UI timer. The screen effects and haptics follow the same schedule, so sound, light and touch stay together.
- **Sounds.** The seven click sounds are synthesised when playback starts, at the output's own sample rate, and are tested for equal loudness, a fast attack and a short length.
- **Sync.** Presets and setlists sync through iCloud key-value storage. Each part of a preset or setlist carries its own change time, so edits made on different devices are combined rather than overwritten. The same result comes out on every device, whatever order the changes arrive in.

## Contributing

Bug reports and ideas are welcome as [issues](https://github.com/arime/metronome/issues). Pull requests are accepted only from collaborators.

## License

Copyright © 2026 Ari Metsähalme. Licensed under the [GNU Affero General Public License v3.0](LICENSE).

The name Snappy Metronome and the app icon are not covered by the licence.
