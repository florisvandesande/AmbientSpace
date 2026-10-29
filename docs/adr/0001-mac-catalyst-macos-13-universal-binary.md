# ADR 0001: Support macOS 13 with a universal Mac Catalyst app and macOS 14 widget

- Status: Accepted
- Date: 2026-10-29

## Context

AmbientSpace is an iOS SwiftUI application that also ships as a Mac Catalyst application and widget extension. The current development machine is an iMac18,3 with an Intel `x86_64` processor, macOS 13.7.8, and Xcode 15.2. The application must run on that machine without changing its existing playback, catalog, widget-state, window, menu, Now Playing, localization, or accessibility behavior. The widget extension has a separate runtime floor because its current App Intent configuration and direct widget actions must remain intact.

Apple Silicon support must remain available. The Mac product therefore has two compatibility requirements:

1. macOS 13.0 must be the minimum system version for the main Mac Catalyst application.
2. macOS 14.0 must remain the minimum system version for the `AmbientSpaceWidgets` extension.
3. The Mac Catalyst application and widget extension must retain both `x86_64` and `arm64` slices in a universal build.

Runtime testing is currently possible only on the Intel iMac. Apple Silicon runtime behavior cannot be confirmed until an Apple Silicon Mac is available.

## Decision

Keep Mac Catalyst as the single macOS implementation. Support macOS 13.0 or later in the main application and macOS 14.0 or later in the `AmbientSpaceWidgets` extension. Build the application and extension as universal products containing `x86_64` and `arm64`.

The shared SwiftUI, catalog, audio, timer, widget-state, and App Intents architecture remains unchanged. The existing App Intent configuration and direct widget actions are part of the contract. On macOS 13, the app runs without a usable widget; on macOS 14 or later, the extension provides the existing widget families and actions. Architecture selection is handled by the build system. It must not introduce separate Intel and Apple Silicon product behavior. If an API requires an availability guard, keep it at the smallest existing platform boundary and preserve the existing user-visible behavior.

Verification records must separate the following evidence:

- Running the app on the iMac verifies the Intel `x86_64` runtime path.
- Inspecting the application and widget binaries verifies that the universal artifact contains `x86_64` and `arm64`.
- Inspecting the application and widget plists verifies `LSMinimumSystemVersion` `13.0` and `14.0`, respectively.
- Running the widget on macOS 14 or later verifies its existing App Intent configuration and direct actions. The absence of a usable widget on macOS 13 is expected.
- Running the app on Apple Silicon is a separate runtime check and remains unverified until that hardware is available.

## Alternatives considered

### Keep macOS 14 for the app and widget

This would preserve the previous application floor but would exclude the Intel iMac because it runs macOS 13.7.8. It does not meet the requirement that the main app run on macOS 13. The widget remains at macOS 14 under the decision.

### Support macOS 13 with an Intel-only binary

This would allow the current iMac to run the app, but it would remove native Apple Silicon support from the shared Mac build and would require a separate arm64 distribution path. It creates an unnecessary packaging distinction and fails the requirement that Apple Silicon support remain intact.

### Create a separate native AppKit application

This would make it possible to tailor the Mac implementation to Intel and Apple Silicon independently, but it would duplicate the existing SwiftUI, playback, catalog, widget, and timer integration. It expands the maintenance surface and could cause behavior to diverge between iOS and Mac. The existing Mac Catalyst boundary is sufficient.

## Consequences

### Positive consequences

- The current Intel iMac can be used for local Mac runtime verification.
- One universal Mac Catalyst build serves Intel and Apple Silicon Macs.
- Existing shared behavior remains in one implementation.
- Future employees can distinguish runtime evidence from build-artifact evidence when reading verification results.

### Costs and limitations

- The main Mac Catalyst application is constrained to APIs available on macOS 13.0, while the widget extension is constrained to APIs available on macOS 14.0. Newer APIs require availability checks or supported alternatives at the relevant boundary.
- Universal binaries may be larger than a single-architecture binary.
- An Intel runtime test cannot prove Apple Silicon runtime behavior. A later Apple Silicon run remains required before claiming full cross-hardware verification.
- macOS 13 users can run the app but cannot use the AmbientSpaceWidgets extension. This is an intentional compatibility boundary, not an installation failure.
- The existing App Intent configuration and direct widget actions must be retained when the widget's deployment target is adjusted.
- Distribution signing, notarization, and production packaging remain separate concerns and are not introduced by this decision.

## Verification expectations

The Mac deployment workflow must validate the bundle identifier, embedded widget extension, installation, launch, and an existing playback interaction. A separate artifact check must validate both architecture slices and the distinct plist values: app `13.0`, widget `14.0`. The project documentation must record the Xcode 15.2 Intel baseline and retain older verification entries as historical records rather than presenting them as current Apple Silicon runtime evidence.
