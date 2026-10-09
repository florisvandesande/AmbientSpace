# Verification record

## 2026-10-07 — Final Mac Catalyst interaction, resizing, and install

- The installed app was tested through macOS Accessibility. Clicking the empty trailing area of the first row changed its label from `Speel Bos` to `Pauzeer Bos` and expanded the description, confirming that the whole visible row starts playback.
- The installed window resized from `720 × 826` to `880 × 906` through a real lower-right resize drag. The title text is hidden while the standard macOS window controls remain visible.
- The screenshot after resizing showed a single continuous row gradient, with no second opaque inner button gradient.
- The Python suite passed all 17 tests, the portable Swift package passed all 19 tests, the generic iOS build and build-for-testing passed, the unsigned Mac Catalyst build passed, the deploy script shell check passed, and `git diff --check` passed.
- The final app was installed at `~/Applications/AmbientSpace.app`, its bundle identifier and embedded widget extension were validated, and it was launched successfully. The previous installation was preserved in a timestamped `.previous` backup beside the app.

## 2026-10-07 — Mac Catalyst minimum window size

- Changed both SwiftUI content sizing and the Catalyst scene restriction to a 200 × 200 point minimum so the limit is applied consistently by the content and native window layers.
- On the installed app, requesting `160 × 160` was clamped to `200 × 232`: the content area reached 200 × 200 points and the standard 32-point title bar remained part of the outer window frame. The window was restored to `720 × 826` after this check.

## 2026-10-07 — Mac Catalyst window and row styling

- Track rows now use the plain button style so the text and icon area is transparent and the row's metadata gradient remains visible without a second inner gradient or button fill.
- The Catalyst window has explicit usable minimum dimensions and supports freeform resizing. Its title text is hidden through the Catalyst titlebar API while the standard macOS window controls remain available.
- The unsigned Mac Catalyst build passed after these changes for the `arm64` Mac destination. The generic iOS build also passed for the shared SwiftUI source.
- `scripts/deploy_macos.example.sh` built, validated the app and embedded widget extension, installed the app to the user's `~/Applications/AmbientSpace.app`, launched it, and confirmed a running Catalyst process.

## 2026-10-07 — Mac Catalyst target

- Added a Mac Catalyst configuration to the existing AmbientSpace app and widget target. The Mac build uses a separate application plist, targets macOS 14 or later in the current Xcode environment, and keeps the iOS plist unchanged.
- Added a resizable desktop window, a localized Playback menu, and keyboard shortcuts for play/pause and previous/next sound selection. The commands use the existing `AudioPlaybackController`.
- Kept the audio engine, catalog, app volume, sleep timer, App Intents, and metadata-only widget state shared with iOS. Catalyst uses macOS's normal application-audio mixing; iOS-only AVAudioSession interruption handling, Live Activity, Lock Screen widgets, and Control Center controls are excluded from the Catalyst build.
- The unsigned Mac Catalyst build succeeded with Xcode 27.0 and the macOS 27.0 SDK. Both the `AmbientSpace` app and `AmbientSpaceWidgets` extension compiled and were embedded in the generated `.app`.
- `scripts/deploy_macos.example.sh` passed shell syntax/help checks and was run on this Mac with the local bundle identifier. It built unsigned, validated the app and widget bundle, installed to `~/Applications/AmbientSpace.app`, launched the app, and confirmed a running Catalyst process.
- The Python suite passed all 17 tests and the portable Swift package passed all 19 tests. `git diff --check` passed.
- A separate manual Mac accessibility, media-key, mixing, widget, signing, and notarization session remains required before public Mac distribution. See the Mac checklist in `TESTING.md`.

## 2026-10-01 — interactive controls, widgets, and refreshed documentation

- Added configurable iOS 18 sound controls, interactive Small and Lock Screen widgets, App Group playback state, metadata-only widget catalog generation, and complete interface localization for all seven supported languages.
- Confirmed that subtitles in the app and Live Activity use leading multiline alignment. The maintainer verified the app result on an iPhone 15 Pro.
- The Python suite passed all 17 tests. The portable Swift package passed all 19 tests.
- An unsigned generic iPhone build passed with the installed Xcode and iOS SDK. `build-for-testing` also succeeded for the app, widget, unit-test, and UI-test targets on the generic iOS Simulator destination.
- A signed Debug build was built, installed, launched, and verified on a physical iPhone 15 Pro with the local ignored deployment script.
- The five maintainer-supplied screenshots were reviewed for visible personal data. They contain no name, e-mail address, account, device identifier, signing identifier, or credential. Their embedded metadata was removed before publication.
- The publishable deployment example contains no personal device or signing-team identifier. The real local deployment script remains ignored by Git.
- Manual checks for every widget layout, every iOS 18 control location, accessibility settings, and every supported language remain listed in `TESTING.md`; the automated build does not replace those checks.

## 2026-09-03 — documentation and source publication preparation

- The maintainer requested a README with the existing app icon, screenshots, and a Codex Sol development credit, followed by a push and merge to `main`.
- The maintainer explicitly requested that tests not be rerun. No new test suite or app build was run for this documentation update. The September 2 results below remain the latest recorded results.
- App source code, audio behavior, and local recordings were not changed by this documentation update. The public source is presented as a preview, with known limitations visible in the README.
- The maintainer supplied three current iPhone screenshots: the sound library, app-only volume, and sleep timer. They were reviewed and copied unchanged into `docs/images/`. They show the white-text design in dark appearance and Dutch, but are not evidence of a new automated test run or of background-audio behavior.

## 2026-09-02 — source and app checks

### Source-only publication review

- Verified that all four local recording folders and representative future/hidden folders are ignored. `audio-files/README.md` remains eligible for Git. No audio files are currently tracked or present in the local Git history.
- Created a temporary source copy using Git's tracked and untracked non-ignored file list. Its `audio-files/` directory contained only `README.md`; the owner's originals were untouched. This is a release-candidate working-tree copy, not a checkout of a new commit.
- The source-only copy passed an unsigned generic iPhone build with Xcode 15.2 / iOS 17.2 and generated `schemaVersion: 1` with an empty track list.
- The same copy passed 15 portable Swift tests, 13 Python tests, and the deployment script's shell syntax check.
- A targeted source scan found no private-key headers, common GitHub/AWS credential patterns, personal development team, or hardcoded developer-home path. This was not a comprehensive security audit or a check of remote repository settings.
- The existing root MIT License was confirmed. The older publication checklist's claim that the license was missing was corrected. No license, repository visibility, commit, push, or device deployment was changed by this review.

### Latest adjustment: white row content and 50% saturation

- Titles, subtitles, descriptions, and play/pause symbols now stay white in both appearances. Inactive rows use 50% saturation; active colors and opacity are unchanged. Adaptive contrast code was removed.
- Xcode 15.2 / iOS 17.2 SDK: unsigned generic iPhone build passed.
- Swift package: 15 tests passed, including four tests for RGB parsing and row saturation. The obsolete adaptive-contrast tests were replaced with tests for the new behavior.
- Python: 13 tests passed. Whitespace checks passed.
- No on-device verification was recorded for this adjustment on September 2. The maintainer subsequently supplied current screenshots on September 3, as recorded above. The automated physical-device results and deployment below refer to the earlier adaptive-text version, not this white-text update.

### Earlier adaptive-text version: completed checks

- Xcode 15.2, iOS 17.2 SDK, deployment target 17.0: unsigned generic iPhone build passed.
- Python: 13 tests passed, including catalog validation, safe output paths, translations, and localization placeholder coverage.
- Swift package on macOS: 19 tests passed for catalog/queue behavior, translation fallback, app volume on all crossfade decks, mute, rapid pause/resume, sleep timing, and gradient contrast.
- Shell syntax check and deploy-script help passed.
- Physical iPhone 15 Pro, iOS 26.6, built with the iOS 17.2 SDK: 30 tests passed (24 unit tests and 6 UI tests). The latest run completed at 14:24 local time. Tests cover both popovers below their buttons, expansion without playback, Dutch/English/French/German interface text, and the new gradient behavior.
- Reviewed physical-device screenshots of the four current palettes, playing/paused rows, and expanded descriptions in light and dark appearance. The dark row overlay is absent; row text uses its local gradient contrast rather than the phone's appearance, while play/pause icons follow their material. Maximum Dynamic Type was also exercised with expanded/scrolled text.
- Mixed gradients remain a contrast trade-off: for example, dark text in the night-rain description has less contrast at the darker right side. No claim is made that every point reaches 4.5:1, and no dark layer was reintroduced.
- All four current audio files were recognized as stereo AAC, approximately one hour each.
- All four covers are square. The rainstorm cover is 845 × 845; the other covers exceed 1024 × 1024. The 1024-pixel size is a recommendation, not a build requirement.
- The current media folder is approximately 546 MB; the simulator app bundle is approximately 555 MB. Source media was not recompressed or resized.

### Environment issues and remaining checks

- Two iOS 17.2 simulator runs stalled on black screens before launching the tests. They are not recorded as passing tests.
- Physical-device tests completed after the owner unlocked the phone.
- Maximum Dynamic Type exposed existing symbol overflow: header and playback symbols grow beyond their fixed-size material circles, and the header status truncates. These layout issues were not changed in this color-only update. Expanded recording text wraps and scrolls.
- Listening checks with another audio app, hardware volume, Bluetooth, interruption handling, VoiceOver, Reduce Motion, and Reduce Transparency still require the manual checklist in TESTING.md.
- Newer SDK builds and media redistribution rights are not verified here.

### Device deployment

The updated color-change Debug build was installed wirelessly on the iPhone 15 Pro running iOS 26.6 and verified through devicectl at 14:28 local time. Bundle identifier: `com.florisvandesande.AmbientSpace`, version 1.0 (1). The build used Xcode 15.2 and the iOS 17.2 SDK. It starts paused and follows the phone's normal language and appearance preferences. Automatic launch after installation was denied because the phone had locked again; the preceding on-device test run successfully launched and exercised this source version.
