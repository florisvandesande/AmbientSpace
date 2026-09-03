# Verification record

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
