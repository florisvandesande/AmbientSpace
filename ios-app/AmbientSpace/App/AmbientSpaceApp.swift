import SwiftUI

@main
struct AmbientSpaceApp: App {
    @StateObject private var playback = AudioPlaybackController()

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            ContentView(playback: playback)
                .modifier(AppearanceTestOverrides())
            #else
            ContentView(playback: playback)
            #endif
        }
    }
}

#if DEBUG
// UI tests can exercise appearance without changing the owner's phone settings.
// Normal launches inherit both values from the system; Release has no override.
private struct AppearanceTestOverrides: ViewModifier {
    @Environment(\.dynamicTypeSize) private var systemTextSize
    private let environment = ProcessInfo.processInfo.environment

    private var requestedColorScheme: ColorScheme? {
        switch environment["AMBIENTSPACE_TEST_APPEARANCE"] {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(requestedColorScheme)
            .dynamicTypeSize(environment["AMBIENTSPACE_TEST_LARGE_TEXT"] == "1" ? .accessibility5 : systemTextSize)
    }
}
#endif
