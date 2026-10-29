# Testing AmbientSpace

## Verification contract for Mac Catalyst

The main Mac Catalyst application supports macOS 13.0 and later. The `AmbientSpaceWidgets` extension remains available only on macOS 14.0 and later. Both products remain universal where built: the application and embedded widget executable must contain `x86_64` for Intel Macs and `arm64` for Apple Silicon Macs. A macOS 13 run verifies the app without a usable widget; a macOS 14 or later run is required to verify the widget.

The local verification baseline is an iMac18,3 with an Intel `x86_64` processor, macOS 13.7.8, and Xcode 15.2. A successful run on this machine is Intel runtime verification for the macOS 13 app; it does not verify widget availability. Inspecting an `arm64` slice in the universal build proves that Apple Silicon code is present, but it is not an Apple Silicon runtime test. Do not report Apple Silicon runtime compatibility as tested until the application has been run on Apple Silicon hardware.

## Automated tests

From the repository root:

```bash
python3 -m unittest discover -s scripts/tests -p 'test_*.py'
bash -n scripts/deploy_ios_to_iphone.sh
bash -n scripts/deploy_macos.example.sh
bash scripts/tests/test_deploy_macos.sh
swift test --scratch-path /tmp/AmbientSpaceCoreTests
```

The Mac deployment contract test uses real Mach-O fixtures and the installed macOS `lipo` command. It verifies universal-binary success for the app and widget, failure when the arm64 slice is missing, the separate minimum-system-version checks, and the identifier-based playback interaction without faking `lipo` output. `lipo` is therefore required on macOS for this test and for the deployment script's universal-artifact validation.

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

Build and inspect the universal Mac Catalyst artifact:

```bash
xcodebuild build \
  -project ios-app/AmbientSpace.xcodeproj \
  -scheme AmbientSpace \
  -destination 'generic/platform=macOS,variant=Mac Catalyst' \
  -derivedDataPath /tmp/AmbientSpaceUniversalBuild \
  ARCHS='x86_64 arm64' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO

lipo -info /tmp/AmbientSpaceUniversalBuild/Build/Products/Debug-maccatalyst/AmbientSpace.app/Contents/MacOS/AmbientSpace
lipo -info /tmp/AmbientSpaceUniversalBuild/Build/Products/Debug-maccatalyst/AmbientSpace.app/Contents/PlugIns/AmbientSpaceWidgets.appex/Contents/MacOS/AmbientSpaceWidgets
APP_PATH=/tmp/AmbientSpaceUniversalBuild/Build/Products/Debug-maccatalyst/AmbientSpace.app
WIDGET_PATH="$APP_PATH/Contents/PlugIns/AmbientSpaceWidgets.appex"
plutil -extract LSMinimumSystemVersion raw -o - "$APP_PATH/Contents/Info.plist"
plutil -extract LSMinimumSystemVersion raw -o - "$WIDGET_PATH/Contents/Info.plist"
```

Expected evidence is `x86_64 arm64` in both `lipo` results. The application plist must print `13.0`; the widget plist must print `14.0`. The exact `lipo` wording can vary between Xcode versions; the required architecture names must be present. These are separate minimum-system-version checks: do not copy the app's `13.0` value to the widget extension.

The deployment workflow is the preferred app end-to-end check because it validates the built bundle, embedded widget extension, installation, launch, and a real interaction. It does not replace the architecture and plist inspection above. Run the ignored local wrapper created from the committed example when it is available:

```bash
BUNDLE_ID=com.example.ambientspace \
  scripts/deploy_macos.sh
```

Use `--build-only` when installation or launch is not required. A deployment on the Intel iMac must execute the app's `x86_64` slice. The universal artifact and split plist checks above must still be run separately; an Intel-only build is insufficient evidence for Apple Silicon support, and a macOS 13 run cannot verify widget availability.

The full deployment flow clicks an existing track row using its accessibility identifier, so the terminal that starts the script needs Accessibility access under **System Settings > Privacy & Security > Accessibility**. If that permission cannot be granted, use `--no-launch` to install and validate the bundle without launching it. Use `--build-only` to skip installation and launch as well.

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

Run the **AmbientSpace** scheme on **My Mac (Mac Catalyst)** in Xcode 15.2 or a newer toolchain. On the verification iMac, **My Mac** runs the Intel `x86_64` slice:

- Resize the window by dragging its lower-right corner and by using the green zoom control. Confirm the content area can reach 200 × 200 points; the standard title bar adds its own height to the outer frame. Confirm the library remains usable at narrow and wide desktop sizes. Check light and dark appearance, Dynamic Type, VoiceOver focus order, keyboard focus, and Reduce Motion.
- Confirm the title text beside the standard macOS window controls is hidden while the controls remain available. Confirm each track row shows one continuous metadata gradient without a darker inner button rectangle, and click empty space in a row to start or pause its sound.
- Start a sound, use the **Playback** menu, and verify the space bar toggles playback while **⌘←** and **⌘→** select the previous and next sounds.
- Confirm the app volume slider changes AmbientSpace only. Play audio in another Mac app and check background mixing.
- Switch to foreground mode and verify the current title, subtitle, cover artwork, Now Playing metadata, and media commands. Remember that macOS does not provide iOS's exclusive audio-session behavior.
- On macOS 13, confirm that the app launches and plays audio without expecting a usable AmbientSpace widget. Do not record the missing widget as an app failure.
- On macOS 14 or later, configure the AmbientSpace widget in a small, medium, and large family where offered. Verify the existing App Intent configuration and each direct widget action while the app is open and closed.
- Confirm that iOS-only Live Activity, Dynamic Island, Lock Screen, and Control Center surfaces are not expected on Mac Catalyst.

The deployment script's full local flow verifies the built bundle identifier, embedded widget extension, installation, and launch. The commands above verify architectures and the separate `13.0` app and `14.0` widget minimum-system-version values. The script uses an unsigned build by default; a signed run requires an explicit `--signed --team TEAM_ID`.

Record the results using these categories:

- **Intel runtime:** the application installed and remained running on the iMac, and the existing playback interaction worked.
- **Universal artifact:** the application and widget extension contain both `x86_64` and `arm64`; the app declares macOS 13.0 and the widget declares macOS 14.0 as their minimum system versions.
- **Widget runtime:** only record this category after a macOS 14 or later run verifies the configured widget families and direct actions. A macOS 13 run has no usable widget by design.
- **Apple Silicon runtime:** leave this explicitly unverified until the same application has been run on an Apple Silicon Mac.

Simulator tests cannot verify real mixing, hardware volume, Bluetooth routing, listening quality, or every system interruption. A successful deployment verifies installation and launch, not this entire listening checklist. If a macOS 14 widget is missing, first verify the host OS and the widget plist value before changing App Intent or widget-action code; on macOS 13 the missing widget is expected.
