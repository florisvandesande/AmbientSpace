# Testing AmbientSpace

## Automated tests

From the repository root:

```bash
python3 -m unittest discover -s scripts/tests -p 'test_*.py'
bash -n scripts/deploy_ios_to_iphone.sh
bash -n scripts/deploy_macos.example.sh
swift test --scratch-path /tmp/AmbientSpaceCoreTests
```

List installed simulator destinations:

```bash
xcrun simctl list devices available
```

Replace `SIMULATOR_ID` with an available iPhone identifier:

```bash
xcodebuild test \
  -project ios-app/AmbientSpace.xcodeproj \
  -scheme AmbientSpace \
  -destination 'platform=iOS Simulator,id=SIMULATOR_ID' \
  -derivedDataPath /tmp/AmbientSpaceTests \
  CODE_SIGNING_ALLOWED=NO
```

Build the Mac Catalyst app and widget extension without signing:

```bash
xcodebuild build \
  -project ios-app/AmbientSpace.xcodeproj \
  -scheme AmbientSpace \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  -derivedDataPath /tmp/AmbientSpaceCatalystBuild \
  CODE_SIGNING_ALLOWED=NO
```

Test the deployment script without installing or launching:

```bash
BUNDLE_ID=com.example.ambientspace \
  scripts/deploy_macos.example.sh --build-only
```

The Mac Swift package runs the portable catalog, translation, audio-engine, gradient, and timer tests without a simulator. The Xcode suite additionally tests the iOS playback controller/session and interface. Together these cover catalog compatibility/order, queue wraparound, translation fallback, playback state, independent volume, fade overlap, rapid pause/resume, and absolute sleep timing. Gradient tests check RGB parsing, original versus 50%-saturated colors, unchanged neutral grays, and all four current recording palettes.

UI tests check popover position, four interface languages, and description behavior. Color tests capture playing/paused rows and expanded descriptions in light and dark appearance, plus maximum Dynamic Type. Optional-recording tests skip when their media is absent. UI tests save screenshots as test-result attachments; passing assertions alone do not prove visual contrast.

The Mac Catalyst build is compile-checked separately because the existing UI tests exercise iPhone-specific popover placement and system surfaces. The current Mac manual checklist is below.

Debug builds accept the test-only launch environment values `AMBIENTSPACE_TEST_APPEARANCE=light` or `dark` and `AMBIENTSPACE_TEST_LARGE_TEXT=1`. The interface tests use these to control appearance without changing the owner's phone settings. Normal launches inherit system preferences; Release builds exclude these overrides. There is no in-app appearance or language setting.

The Python tests include empty catalogs, invalid input, duplicate indexes, translations, removing old tracks, and source/output path safety. Localization tests check translation coverage and matching format placeholders.

## Physical-device checks before release

Use at least two real recordings of twelve seconds or longer.

- Play audio in another app, start AmbientSpace in background mode, and lower AmbientSpace to 25% and then 0%. Confirm only AmbientSpace changes and the phone's system-volume indicator remains unchanged.
- Switch recordings while changing app volume; listen to both the outgoing and incoming recording. Wait for at least two complete loops.
- Pause/resume rapidly, then pause normally. Confirm that the visible play state matches the audible state.
- Lock the phone, leave the app, and return. Confirm background playback and timer behavior.
- Switch to foreground mode: check title, subtitle, cover, play/pause, and previous/next with wraparound. Switch back and check the other app's controls.
- With a sound that has `sfSymbol` configured, verify the symbol in the library, foreground Lock Screen artwork, Control Center, and the Live Activity. Verify an empty value falls back to Play in the library and cover artwork in foreground mode.
- On iOS 18 or later, add both AmbientSpace controls to Control Center and the Lock Screen. Verify random playback and a configured sound while the app is closed, backgrounded, and open.
- On a Dynamic Island device, start playback and verify the current sound symbol and name. Switch sounds, pause, and resume; then tap the Live Activity and confirm AmbientSpace opens.
- Disconnect headphones and simulate an interruption. Check that audio does not restart unexpectedly.
- Set a one-minute timer. During the final fifteen seconds, change app volume or switch recordings. Confirm the deadline is not extended and the fade is not reset. Cancel a fading timer and confirm the selected app volume returns.
- Open volume and timer popovers. Both should appear below their buttons; tap outside to dismiss.
- Expand and collapse descriptions. The moving description must stay below the subtitle and must not toggle playback.
- Check original colors while playing and 50%-saturated colors while paused. Neither state should have a dark overlay. Titles, subtitles, descriptions, and play/pause symbols must stay white in both light and dark appearance, including throughout expansion. Inspect pale areas specifically: white text does not guarantee sufficient contrast over every metadata color.
- Check Dutch, English, French, and German through the phone's language preferences. Include Lock Screen metadata.
- Check light/dark appearance, a small display, maximum Dynamic Type, VoiceOver, Reduce Motion, and Reduce Transparency. Popover contents must remain reachable by scrolling when necessary.

## Mac Catalyst checks

Run the **AmbientSpace** scheme on **My Mac (Mac Catalyst)** in Xcode:

- Resize the window by dragging its lower-right corner and by using the green zoom control. Confirm the content area can reach 200 × 200 points; the standard title bar adds its own height to the outer frame. Confirm the library remains usable at narrow and wide desktop sizes. Check light and dark appearance, Dynamic Type, VoiceOver focus order, keyboard focus, and Reduce Motion.
- Confirm the title text beside the standard macOS window controls is hidden while the controls remain available. Confirm each track row shows one continuous metadata gradient without a darker inner button rectangle, and click empty space in a row to start or pause its sound.
- Start a sound, use the **Playback** menu, and verify the space bar toggles playback while **⌘←** and **⌘→** select the previous and next sounds.
- Confirm the app volume slider changes AmbientSpace only. Play audio in another Mac app and check background mixing.
- Switch to foreground mode and verify the current title, subtitle, cover artwork, Now Playing metadata, and media commands. Remember that macOS does not provide iOS's exclusive audio-session behavior.
- If macOS offers the AmbientSpace widget, configure the controls widget in a small, medium, and large family and verify its actions while the app is open and closed.
- Confirm that iOS-only Live Activity, Dynamic Island, Lock Screen, and Control Center surfaces are not expected on Mac Catalyst.

The deployment script's full local flow also verifies the built bundle identifier, embedded widget extension, installation, and launch. It uses an unsigned build by default; a signed run requires an explicit `--signed --team TEAM_ID`.

Simulator tests cannot verify real mixing, hardware volume, Bluetooth routing, listening quality, or every system interruption. A successful deployment verifies installation and launch, not this entire listening checklist.
