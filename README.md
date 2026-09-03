<h1 align="center">AmbientSpace</h1>

<p align="center">
  <img src="ios-app/AmbientSpace/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" width="112" height="112" alt="AmbientSpace app icon: blue and violet waves">
</p>

<p align="center">Ambient recordings, at your own volume.</p>

<p align="center">
  iPhone · iOS 17+ · SwiftUI · <a href="LICENSE">MIT licensed</a> · Preview
</p>

<p align="center">
  <a href="#getting-started">Getting started</a> ·
  <a href="audio-files/README.md">Add sounds</a> ·
  <a href="#install-on-an-iphone">Install on iPhone</a> ·
  <a href="CONTRIBUTING.md">Contribute</a>
</p>

AmbientSpace is a small, native iPhone app for looping ambient recordings. Mix a quiet background with music from another app, or give AmbientSpace its own Lock Screen controls. It uses SwiftUI and Apple's audio frameworks, without a backend, accounts, analytics, streaming, or third-party packages.

**Preview status:** this is a buildable source project, not a finished App Store release. Bring your own recordings; no audio library is included. Known limitations and dated test results are listed below.

## Features

- **Independent volume.** Turn AmbientSpace down without changing another app's volume. Hardware volume buttons still control the phone's system volume.
- **Looping and transitions.** One recording at a time, with a six-second crossfade at loop boundaries and when switching recordings.
- **Two audio modes.** Background mode mixes with other apps. Foreground mode provides artwork and play, pause, previous, and next controls on the Lock Screen.
- **Sleep timer.** Choose 15, 30, 45, or 60 minutes, or a custom duration from one minute to twelve hours. Audio fades during the final fifteen seconds.
- **A simple library.** Color gradients come from recording metadata. Tap a title to reveal its description; use the separate button to play or pause.
- **Four interface languages.** English, Dutch, French, and German follow the phone's language preferences. There is no in-app language setting. Recording translations are optional.

The app starts paused, in background mode, at 100% app volume. Playback state, app volume, mode, and timer are not saved between full launches.

## Screenshots

iPhone screenshots supplied by the maintainer on September 3, 2026, showing the Dutch interface in dark appearance. The local recordings and covers shown in the library are not included in this repository.

<table>
  <tr>
    <th>Sound library</th>
    <th>App-only volume</th>
    <th>Sleep timer</th>
  </tr>
  <tr>
    <td><img src="docs/images/overview.jpg" width="240" alt="AmbientSpace sound library with white labels and rainstorm playing"></td>
    <td><img src="docs/images/volume.jpg" width="240" alt="AmbientSpace volume at 61 percent with foreground mode switched off"></td>
    <td><img src="docs/images/sleep-timer.jpg" width="240" alt="Sleep timer with four presets and a custom duration selector"></td>
  </tr>
</table>

## Requirements

- A Mac with Xcode 15.2 or later and an installed iOS SDK.
- iPhone with iOS 17.0 or later.
- Python 3.9 or later, used only during development/building.
- For installation on a physical phone: your own Apple account configured in Xcode and a development signing team.

The project's deployment target is iOS 17.0. The development iMac currently uses Xcode 15.2 with the iOS 17.2 SDK. A newer phone can run this build, but that does not make it a build made with a newer SDK. Check newer SDKs separately before releasing with them.

## Getting started

1. Download or clone the repository.
2. Open `ios-app/AmbientSpace.xcodeproj` in Xcode.
3. Select the **AmbientSpace** scheme.
4. Choose an installed iPhone simulator and press **Run**. No signing team is needed for a simulator.
5. For a physical iPhone, select the AmbientSpace target, then **Signing & Capabilities**. Select your own team. For your own fork, change the bundle identifier to one you control, for example `com.example.ambientspace`.

The app can be built with an empty `audio-files/` folder. It will explain how to add sounds. To add recordings, follow [the audio guide](audio-files/README.md).

The public source contains the audio guide, not the recordings. All other contents of `audio-files/` are ignored by Git, including recording metadata and cover images. Local app builds still bundle your local audio library; excluding it from Git does not exclude it from a shared app binary.

There are no runtime secrets or configuration files to create. Do not add signing certificates, private keys, provisioning profiles, or account credentials to this repository.

### Command-line build without signing

Run from the repository root:

```bash
xcodebuild build \
  -project ios-app/AmbientSpace.xcodeproj \
  -scheme AmbientSpace \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/AmbientSpaceDerivedData \
  CODE_SIGNING_ALLOWED=NO
```

This checks compilation. An unsigned app cannot be installed on a normal iPhone.

## Install on an iPhone

First connect and unlock the phone, trust the Mac, and enable **Developer Mode** under **Settings > Privacy & Security**. In Xcode, make sure your Apple account is signed in. Pair the device in **Window > Devices and Simulators**. Once paired and available on the local network, the script can deploy wirelessly without a separate wireless flag.

List devices:

```bash
scripts/deploy_ios_to_iphone.sh --list
```

Build, sign, install, launch, and verify:

```bash
scripts/deploy_ios_to_iphone.sh --team YOUR_TEAM_ID --device DEVICE_IDENTIFIER
```

Replace the placeholders with your Apple Developer team identifier and the identifier shown by `--list`. If only one iPhone is available, `--device` can be omitted. The script refuses to guess when several phones are available.

For a fork with a different bundle identifier:

```bash
BUNDLE_ID=com.example.ambientspace \
  scripts/deploy_ios_to_iphone.sh --team YOUR_TEAM_ID --device DEVICE_IDENTIFIER
```

`DEVELOPMENT_TEAM=YOUR_TEAM_ID` is also accepted instead of `--team`. These identifiers are not passwords. No personal development team is stored in the script. Build products stay in `/tmp/AmbientSpaceDeviceBuild`, outside the repository.

### Common installation problems

- **No iPhone found:** unlock it, connect a cable, confirm trust, and check Xcode's Devices and Simulators window.
- **Apple session expired:** sign in again under Xcode's Settings > Accounts. A cached profile may still work, but creating or renewing one requires a valid session.
- **Signing or bundle identifier error:** use your own team and a unique bundle identifier. A first installation may require registering the phone with your team in Xcode.
- **Installed but did not launch:** unlock the phone and check Developer Mode and any developer-trust prompt. The script returns an error rather than claiming the entire workflow succeeded.

## Verification and known limitations

Last recorded checks: **September 2, 2026**.

- A source-only copy with an empty audio library built successfully with Xcode 15.2 and the iOS 17.2 SDK. All **15 portable Swift tests** and **13 Python tests** passed.
- An earlier build passed **30 on-device tests** on an iPhone 15 Pro running iOS 26.6.
- Tests were not rerun for the September 3 documentation update. See the [verification record](docs/VERIFICATION.md) for the scope of each check.

Limitations to know before using or contributing:

- Crossfades reduce noticeable loop boundaries, but the result depends on the recording. Long-loop listening, mixing with other apps, Bluetooth routes, interruptions, and timer behavior still need the full physical-device checklist.
- Light and dark appearances are implemented. At the largest accessibility text sizes, some symbols outgrow their buttons and the header text truncates. White text can be difficult to read over pale gradients. VoiceOver, Reduce Motion, and Reduce Transparency still need complete manual verification.
- Fades and the sleep timer are not sample-accurate or hard real-time guarantees. Their timing can be affected by operating-system scheduling.
- The local iOS 17.2 simulators previously stalled. The successful device build does not establish compatibility with every simulator or newer SDK.

### Run the tests

```bash
python3 -m unittest discover -s scripts/tests -p 'test_*.py'
swift test --scratch-path /tmp/AmbientSpaceCoreTests
```

In Xcode, choose an installed iPhone simulator and use **Product > Test**. See [testing instructions](docs/TESTING.md) for command-line tests and the physical-device checklist.

## Development and attribution

This project relied on **Codex Sol** for much of its implementation: app code, development scripts, documentation, and iterative fixes. The maintainer directed the product requirements and visual choices.

## License and media

The source code is provided under the [MIT License](LICENSE). Local recordings, cover images, and their metadata are not distributed in the source repository. The code license does not grant rights to third-party media that someone adds to a local build. Check media rights before sharing any built app.

## Project documentation

- [Audio folders, translations, and validation](audio-files/README.md)
- [Architecture and known limitations](docs/ARCHITECTURE.md)
- [Contributing](CONTRIBUTING.md)
- [Open-source release checklist](docs/OPEN_SOURCE_CHECKLIST.md)
