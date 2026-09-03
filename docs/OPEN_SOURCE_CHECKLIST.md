# Open-source publication checklist

This is a checklist for a code-only source preview, not a declaration that an app binary is ready for general use. The root `LICENSE` contains the MIT License, with copyright credited to "Floris". See [the verification record](VERIFICATION.md) for dated checks and the scope of the publication work.

## Already in place

- MIT license text, beginner build/install instructions, contribution guidance, architecture notes, and tests.
- Maintainer-supplied screenshots of the current library, volume, and timer interface, plus a Codex Sol development credit in the README.
- A source-only build can use an empty audio library; users supply their own recordings.
- `.gitignore` excludes all contents of `audio-files/` except `README.md`, including new folders, metadata, and covers. Local originals are retained.
- No personal signing team is hardcoded in the project or deployment script. Build products and signing material are ignored.

## Before publishing the source

- Check that the copyright credit in `LICENSE` is the desired attribution and confirm the provenance of the app icon and any other included artwork.
- Review and commit the intended app, scripts, documentation, and `.gitignore`, not just the README.
- Inspect staged paths for media, signing keys, profiles, user-specific Xcode files, and private configuration. `.gitignore` does not protect already-tracked files or files added with `--force`. The local history currently contains no `audio-files/` media.
- Build and run tests from the intended source-only release, then repeat from the actual committed checkout before publishing. Review the empty-catalog screen and record the SDK used.
- Mark the initial release as a preview if the physical-device checklist or known accessibility issues remain unresolved. Describe those limits in the release notes.
- Commit, push, and publish only after explicit owner approval.

## Media and app binaries

The local folders `bos`, `nachtelijke_regen`, `regenstorm`, and `riviertje` contain recordings and covers whose redistribution rights have not been verified. They are excluded from the source release. Attribution in a description alone does not establish redistribution permission.

Local builds still scan and bundle ignored audio folders. Do not distribute a locally built app or archive assuming that `.gitignore` removed its media. Before distributing any recording or cover, document its creator, source, license, required attribution, and permission to redistribute. The code's MIT license does not supply permission for third-party recordings or artwork.

## Before calling an app release stable

- Complete the device checklist for the latest white-text / 50%-saturation design. Current screenshots show the interface; the earlier 30-test physical run covered the previous adaptive-text design.
- Fix the known maximum-Dynamic-Type symbol overflow and header truncation. White text on pale gradient colors remains a deliberate readability limitation, not verified contrast compliance.
- Complete listening and device tests for long loops, audio mixing, foreground controls, Bluetooth/headphone routes, interruptions, and sleep-timer fade. Test VoiceOver, Reduce Motion, and Reduce Transparency.
- Verify builds with any newer SDK used for distribution. App Store submission has separate requirements; a public source repository is not an App Store release.

## Useful follow-up work, not prerequisites for open source

- Add continuous integration for Python tests, portable Swift tests, and an unsigned iPhone build.
- Provide a generated or clearly licensed test recording so contributors can exercise row/playback UI tests without the owner's private recordings. Several current UI tests skip when the optional forest recording is absent.
- Keep screenshots current and add a changelog and issue templates.
- Provide a concrete private security-reporting route, for example in `SECURITY.md`.

See [the verification record](VERIFICATION.md) for completed checks and limitations. GitHub's [licensing guidance](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository) and Git's [ignore documentation](https://git-scm.com/docs/gitignore) explain the distinction between licensing, visibility, and ignored files.
