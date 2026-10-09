# Architecture

## Source map

- `App/AmbientSpaceApp.swift` owns the app's playback controller.
- `App/AmbientSpaceApp.swift` also adds the Mac Catalyst window size and Playback menu; the menu delegates to the same controller as the SwiftUI buttons.
- `Models/` defines catalog decoding, recording metadata, translation fallback, and previous/next selection.
- `Models/TrackGradient.swift` parses RGB colors and calculates row saturation without depending on SwiftUI.
- `Audio/AudioPlaybackController.swift` coordinates playback, session mode, interruptions, remote controls, errors, and the sleep timer.
- `Audio/DualPlayerAudioEngine.swift` handles the two looping players and overlap between outgoing/incoming recordings.
- `Audio/AudioSessionManager.swift` is the only place that configures the system audio session.
- `Audio/RemoteControlCoordinator.swift` supplies foreground Lock Screen and Control Center metadata and media commands.
- `Audio/LiveActivityCoordinator.swift` owns the one current playback Live Activity.
- `App/PlaybackIntents.swift` exposes random, global play/pause, and selected-sound playback to App Shortcuts, interactive widgets, and iOS 18 controls.
- `Models/PlaybackWidgetState.swift` defines the versioned App Group state shared with WidgetKit.
- `AmbientSpaceWidgets/` renders the Live Activity, Small widget, Lock Screen widgets, and, when compiled with Xcode 16 or later, configurable system controls.
- `Audio/SleepTimerController.swift` uses an absolute end date, rather than counting timer callbacks.
- `Views/` contains the SwiftUI interface.
- `Support/BottomPopover.swift` anchors native popovers below the buttons, including on the iOS 17 SDK.
- `Resources/Localizable.xcstrings` contains interface and error-message translations.
- `Resources/Info-MacCatalyst.plist` supplies the macOS-specific application metadata while the iOS target keeps its existing plist.
- `scripts/build_audio_catalog.py` runs at build time only. Python is not part of the installed app.

## Independent volume layers

Each player receives the product of its loop gain, track-switch gain, pause/resume gain, sleep-timer gain, and user-selected app volume. The app never writes to the phone's system-volume control.

Outgoing tracks store normalized gains, not already-scaled output volumes. This prevents volume being applied twice during a crossfade, and lets the slider affect all audible decks immediately. App volume and timer gain survive track switches. Canceling a timer restores only the timer layer.

Background mode uses a playback session with `mixWithOthers` on iOS. Foreground mode uses an exclusive session and publishes media controls on iOS. On Mac Catalyst, macOS mixes application audio by default, so `AudioSessionManager` deliberately keeps the session boundary as a no-op; foreground mode still publishes Now Playing metadata and enables media commands. The app starts paused in background mode; no session is activated until playback is requested.

## Widgets and shared state

The app and widget extension use `group.<app bundle identifier>` to share only a versioned current-track identifier and playing flag. The app writes the state at launch and after each playback transition, then asks WidgetKit and, on iOS 18, Control Center to reload. Audio playback always runs in the app process through `AudioPlaybackIntent`; the extension never opens audio files.

The widget target runs the catalog generator in metadata-only mode. Its bundle contains `catalog.json` for configuration labels, translations, SF Symbols, and gradients, but no recordings or cover images. The Small widget selects its fixed one-, two-, four-, or nine-cell layout from the number of configured actions. The nine-cell layout preserves all empty positions. The Mac Catalyst extension exposes the compatible system-small, system-medium, and system-large families; iOS-only Live Activity, Lock Screen, and Control Center configurations are excluded from the Catalyst build.

## Timing and interruptions

The player renders fades every 50 milliseconds while playing, using a monotonic clock. Two players alternate indefinitely so the final six seconds of a recording crossfade into its beginning. The sleep timer uses wall-clock time and refreshes when the app returns to the foreground. The selected end time is not extended by switching sounds or pausing.

A headphone disconnect pauses playback. An interruption resumes only if the app was playing before the interruption and iOS allows resumption. These `AVAudioSession` notifications are iOS-only; macOS uses its normal application-audio routing. App volume does not activate a session or change audio mode.

The clock, audio-player factory, and session/backend boundaries are replaceable in tests. Unit tests do not need to produce audible sound.

## Catalyst runtime boundaries

Mac Catalyst shares the catalog, dual-player engine, sleep timer, app volume, widget state, App Intents, and SwiftUI library with iOS. The Mac-specific boundary is intentionally small:

- The window opens at the system desktop size, remains resizable down to a 200 × 200 point content area, and hides only the title text next to the standard macOS window controls.
- Playback commands are available in the **Playback** menu, with space-bar play/pause and Command-arrow previous/next shortcuts.
- Foreground mode updates Now Playing and media commands. It does not make macOS audio exclusive because Catalyst has no iOS audio-session category to configure.
- Live Activity, Dynamic Island, Lock Screen widgets, and iOS 18 Control Center controls are not compiled for Catalyst. The Mac widget uses the shared metadata-only catalog and runs playback actions through the app process.

## Deliberate limits

- No streaming, downloading, background server, persistence, or in-app language switch.
- The crossfade masks a file boundary but cannot guarantee an inaudible loop for every recording. Avoid abrupt starts/ends, long silence, and mismatched loudness.
- Fades use a main-thread timer, not sample-accurate audio scheduling. Heavy work or operating-system suspension can delay updates. The sleep deadline is rechecked on return; it is not a hard real-time guarantee.
- Very rapid track switching can temporarily keep several outgoing player pairs alive for the six-second fade window.
- The generator validates signatures, not complete media decoding or licensing. Large recordings increase app size.
- The iOS 17-compatible build does not claim newer-SDK-specific visual behavior.
- The Catalyst build currently targets macOS 14 or later. Distribution signing, notarization, and a separate macOS accessibility/listening checklist are not automated in this repository.

## Row colors and text

Playing rows use the two original metadata colors. Paused rows use 50% saturation, calculated by mixing each RGB endpoint halfway toward its neutral gray. Both states are opaque; there is no black backing, dark overlay, or text shadow.

Titles, subtitles, descriptions, and play/pause symbols are always white in both light and dark appearance. The header and popovers continue to use system appearance. Text color does not change during expansion; the previous adaptive contrast measurements and delayed updates have been removed.

Track rows use one plain SwiftUI button with an explicit rounded hit shape, so tapping anywhere in the row starts or pauses playback and also toggles its description. The metadata gradient remains the only row fill; the text and icon area does not add a second opaque or translucent button background.

White text can have limited contrast on pale gradient areas. This is a deliberate visual choice, not a guarantee of accessibility contrast compliance. No metadata fields, user settings, or dark layers are added.
