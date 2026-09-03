# Contributing

Start with the [README](README.md) and [architecture notes](docs/ARCHITECTURE.md). This is a standalone native iPhone app; there is no web/backend runtime to configure.

1. Create a `feature/...` or `bugfix/...` branch.
2. Keep the iOS 17.0 deployment target unless a separate compatibility change has been agreed.
3. Keep code, identifiers, comments, and developer messages in English.
4. Use standard Apple frameworks and Python's standard library before adding dependencies.
5. Add interface text to all four languages in `Localizable.xcstrings`. Add metadata translations for recording-specific text.
6. Add a regression test for behavior changes and run the [test checklist](docs/TESTING.md).
7. Explain what changed, why, how to test it, and any remaining device checks in the pull request.

Do not commit Xcode user settings, build products, signing material, credentials, or recordings/covers without documented redistribution rights. You do not need anyone else's Apple team or provisioning profile to build your own copy.

When reporting a problem, include the iOS version, Xcode version if relevant, audio mode, steps to reproduce, expected behavior, and actual behavior. Do not attach personal account information or private recordings. Report security issues privately to the repository owner rather than posting sensitive details in a public issue.

A contribution policy does not grant a license. Review the [publication checklist](docs/OPEN_SOURCE_CHECKLIST.md) before redistribution.
