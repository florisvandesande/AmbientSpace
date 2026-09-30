// swift-tools-version: 5.9
import PackageDescription

// Run deterministic audio/model tests on a Mac without booting an iOS simulator.
// The application itself is still built with the Xcode project in ios-app/.
let package = Package(
    name: "AmbientSpaceCoreTests",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "AmbientSpace",
            path: "ios-app/AmbientSpace",
            exclude: ["App", "Views", "Support", "Resources", "Audio/AudioPlaybackController.swift", "Audio/AudioSessionManager.swift", "Audio/LiveActivityCoordinator.swift", "Audio/RemoteControlCoordinator.swift", "Models/AmbientPlaybackActivityAttributes.swift"],
            sources: ["Models", "Audio/DualPlayerAudioEngine.swift", "Audio/SleepTimerController.swift"]
        ),
        .testTarget(name: "AmbientSpaceTests", dependencies: ["AmbientSpace"], path: "ios-app/AmbientSpaceTests")
    ]
)
