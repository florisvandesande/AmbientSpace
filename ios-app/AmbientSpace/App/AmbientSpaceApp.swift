import SwiftUI
#if targetEnvironment(macCatalyst)
import UIKit
#endif

@main
struct AmbientSpaceApp: App {
    @StateObject private var playback = AudioPlaybackController.shared

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            ContentView(playback: playback)
                .modifier(AppearanceTestOverrides())
                .modifier(WindowContentSizing())
                .modifier(WindowTitleBarConfiguration())
            #else
            ContentView(playback: playback)
                .modifier(WindowContentSizing())
                .modifier(WindowTitleBarConfiguration())
            #endif
        }
#if targetEnvironment(macCatalyst)
        .windowResizability(.contentSize)
        .commands {
            AmbientSpacePlaybackCommands(playback: playback)
        }
#endif
    }
}

#if targetEnvironment(macCatalyst)
private struct AmbientSpacePlaybackCommands: Commands {
    @ObservedObject var playback: AudioPlaybackController

    var body: some Commands {
        CommandMenu("Playback") {
            Button("Play or pause") {
                if playback.isPlaying {
                    playback.pause()
                } else {
                    playback.resume()
                }
            }
            .keyboardShortcut(.space, modifiers: [])
            .disabled(playback.tracks.isEmpty)

            Divider()

            Button("Previous sound") {
                playback.playPrevious()
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command])
            .disabled(playback.currentTrack == nil)

            Button("Next sound") {
                playback.playNext()
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command])
            .disabled(playback.currentTrack == nil)
        }
    }
}
#endif

private struct WindowContentSizing: ViewModifier {
    func body(content: Content) -> some View {
#if targetEnvironment(macCatalyst)
        content
            .frame(
                minWidth: 200,
                maxWidth: 1600,
                minHeight: 200,
                maxHeight: 1400
            )
#else
        content
#endif
    }
}

private struct WindowTitleBarConfiguration: ViewModifier {
    func body(content: Content) -> some View {
#if targetEnvironment(macCatalyst)
        content.background {
            MacWindowTitleBarConfigurator()
                .frame(width: 0, height: 0)
        }
#else
        content
#endif
    }
}

#if targetEnvironment(macCatalyst)
private struct MacWindowTitleBarConfigurator: UIViewRepresentable {
    func makeUIView(context: Context) -> MacWindowTitleBarView {
        MacWindowTitleBarView(frame: .zero)
    }

    func updateUIView(_ view: MacWindowTitleBarView, context: Context) {
        view.configureTitlebar()
    }
}

private final class MacWindowTitleBarView: UIView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        configureTitlebar()
    }

    func configureTitlebar() {
        guard let window, let windowScene = window.windowScene else { return }

        window.canResizeToFitContent = true
        windowScene.sizeRestrictions?.minimumSize = CGSize(width: 200, height: 200)
        windowScene.sizeRestrictions?.maximumSize = CGSize(width: 10_000, height: 10_000)

        guard let titlebar = windowScene.titlebar else { return }
        titlebar.titleVisibility = .hidden
    }
}
#endif

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
