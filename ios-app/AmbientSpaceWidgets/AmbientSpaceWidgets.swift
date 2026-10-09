import AppIntents
import SwiftUI
import WidgetKit
#if !targetEnvironment(macCatalyst)
import ActivityKit
#endif

private enum WidgetKinds {
    static let controls = "com.florisvandesande.AmbientSpace.sound-grid"
    static let lockScreen = "com.florisvandesande.AmbientSpace.lock-screen-sound"
}

@main
struct AmbientSpaceWidgets: WidgetBundle {
    var body: some Widget {
#if !targetEnvironment(macCatalyst)
        AmbientPlaybackLiveActivity()
#endif
        AmbientSoundGridWidget()
#if !targetEnvironment(macCatalyst)
        AmbientLockScreenSoundWidget()
#endif
#if os(iOS) && !targetEnvironment(macCatalyst) && compiler(>=6.0)
        if #available(iOSApplicationExtension 18.0, *) {
            PlayRandomSoundControl()
            PlaySoundControl()
        }
#endif
    }
}

#if !targetEnvironment(macCatalyst)
struct AmbientPlaybackLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AmbientPlaybackActivityAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: context.state.sfSymbol ?? "waveform")
                    .font(.title2)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.title)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(context.state.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 0)
            }
            .padding()
            .activityBackgroundTint(Color(uiColor: .systemBackground))
            .activitySystemActionForegroundColor(.primary)
            .widgetURL(URL(string: "ambientspace://now-playing"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.sfSymbol ?? "waveform").font(.title2)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title)
                        .font(.headline)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: context.state.sfSymbol ?? "waveform")
            } compactTrailing: {
                Image(systemName: "waveform")
            } minimal: {
                Image(systemName: context.state.sfSymbol ?? "waveform")
            }
            .widgetURL(URL(string: "ambientspace://now-playing"))
            .keylineTint(.blue)
        }
    }
}
#endif

struct SoundWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: SoundWidgetConfigurationIntent
    let playback: PlaybackWidgetState
    let currentTrack: AudioTrack?
}

struct SoundWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SoundWidgetEntry {
        SoundWidgetEntry(
            date: .now,
            configuration: SoundWidgetConfigurationIntent(),
            playback: PlaybackWidgetState(currentTrackID: nil, isPlaying: false),
            currentTrack: nil
        )
    }

    func snapshot(for configuration: SoundWidgetConfigurationIntent, in context: Context) async -> SoundWidgetEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: SoundWidgetConfigurationIntent, in context: Context) async -> Timeline<SoundWidgetEntry> {
        Timeline(entries: [entry(for: configuration)], policy: .never)
    }

    private func entry(for configuration: SoundWidgetConfigurationIntent) -> SoundWidgetEntry {
        let playback = PlaybackWidgetStateStore().load()
        let tracks = (try? AudioCatalogLoader(bundle: .main).load().tracks) ?? []
        return SoundWidgetEntry(
            date: .now,
            configuration: configuration,
            playback: playback,
            currentTrack: tracks.first { $0.id == playback.currentTrackID }
        )
    }
}

struct AmbientSoundGridWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetKinds.controls,
            intent: SoundWidgetConfigurationIntent.self,
            provider: SoundWidgetProvider()
        ) { entry in
            AmbientSoundGridView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetAmbientBackground(track: entry.currentTrack, isPlaying: entry.playback.isPlaying)
                }
        }
        .configurationDisplayName("AmbientSpace controls")
        .description("Choose up to nine sound controls.")
#if targetEnvironment(macCatalyst)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
#else
        .supportedFamilies([.systemSmall])
#endif
        .contentMarginsDisabled()
    }
}

private struct AmbientSoundGridView: View {
    let entry: SoundWidgetEntry

    private var actions: [AmbientWidgetActionEntity?] { entry.configuration.positions }
    private var configured: [AmbientWidgetActionEntity] { actions.compactMap { $0 } }

    var body: some View {
        Group {
            switch SoundWidgetLayout.layout(configuredCount: configured.count) {
            case .empty:
                ContentUnavailableView {
                    Label("Configure widget", systemImage: "slider.horizontal.3")
                }
            case .single:
                largeButton(configured[0])
            case .twoPills:
                VStack(spacing: 10) {
                    pillButton(configured[0])
                    pillButton(configured[1])
                }
            case .fourCells:
                let compactActions = configured.map(Optional.some) + Array(repeating: nil, count: 4 - configured.count)
                fixedGrid(columns: 2, actions: compactActions)
            case .nineCells:
                fixedGrid(columns: 3, actions: actions)
            }
        }
        .padding(14)
        .foregroundStyle(.white)
    }

    private func largeButton(_ action: AmbientWidgetActionEntity) -> some View {
        Button(intent: PerformWidgetActionIntent(action: action)) {
            VStack(alignment: .leading) {
                HStack {
                    Spacer()
                    Image(systemName: symbol(for: action)).font(.title2.weight(.bold))
                }
                Spacer()
                Text(action.title)
                    .font(.headline.weight(.bold))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func pillButton(_ action: AmbientWidgetActionEntity) -> some View {
        Button(intent: PerformWidgetActionIntent(action: action)) {
            HStack {
                Text(action.title.split(separator: " ").first.map(String.init) ?? action.title)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                Spacer(minLength: 6)
                Image(systemName: symbol(for: action)).font(.body.weight(.bold))
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func fixedGrid(columns: Int, actions: [AmbientWidgetActionEntity?]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
            ForEach(actions.indices, id: \.self) { index in
                if let action = actions[index] {
                    Button(intent: PerformWidgetActionIntent(action: action)) {
                        Image(systemName: symbol(for: action))
                            .font(columns == 2 ? .title2.weight(.bold) : .body.weight(.bold))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    private func symbol(for action: AmbientWidgetActionEntity) -> String {
        action.kind == .playPause && entry.playback.isPlaying ? "pause.fill" : action.sfSymbol
    }
}

private struct WidgetAmbientBackground: View {
    let track: AudioTrack?
    let isPlaying: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let first = Color(widgetHex: track?.colorStart) ?? Color(red: 0.16, green: 0.20, blue: 0.30)
        let second = Color(widgetHex: track?.colorEnd) ?? Color(red: 0.35, green: 0.25, blue: 0.46)
        LinearGradient(
            colors: [
                colorScheme == .dark ? .black : .white,
                first.opacity(colorScheme == .light ? (isPlaying ? 0.75 : 0.45) : (isPlaying ? 0.32 : 0.16)),
                second.opacity(colorScheme == .light ? (isPlaying ? 0.85 : 0.55) : (isPlaying ? 0.40 : 0.20)),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private extension Color {
    init?(widgetHex: String?) {
        guard let widgetHex, widgetHex.count == 7, widgetHex.first == "#",
              let value = UInt64(widgetHex.dropFirst(), radix: 16) else { return nil }
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255,
            opacity: 1
        )
    }
}

#if !targetEnvironment(macCatalyst)
struct LockScreenSoundEntry: TimelineEntry {
    let date: Date
    let configuration: LockScreenSoundConfigurationIntent
}

struct LockScreenSoundProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LockScreenSoundEntry {
        LockScreenSoundEntry(date: .now, configuration: LockScreenSoundConfigurationIntent())
    }

    func snapshot(for configuration: LockScreenSoundConfigurationIntent, in context: Context) async -> LockScreenSoundEntry {
        LockScreenSoundEntry(date: .now, configuration: configuration)
    }

    func timeline(for configuration: LockScreenSoundConfigurationIntent, in context: Context) async -> Timeline<LockScreenSoundEntry> {
        Timeline(entries: [LockScreenSoundEntry(date: .now, configuration: configuration)], policy: .never)
    }
}

struct AmbientLockScreenSoundWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetKinds.lockScreen,
            intent: LockScreenSoundConfigurationIntent.self,
            provider: LockScreenSoundProvider()
        ) { entry in
            LockScreenSoundView(sound: entry.configuration.sound)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Lock Screen sound")
        .description("Show and control a chosen AmbientSpace sound.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

private struct LockScreenSoundView: View {
    let sound: AmbientSoundEntity?
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let sound {
            Button(intent: PlaySoundIntent(sound: sound)) {
                switch family {
                case .accessoryRectangular:
                    HStack(spacing: 8) {
                        Image(systemName: sound.sfSymbol ?? "waveform").font(.title3)
                        Text(sound.title).font(.headline).lineLimit(2)
                        Spacer(minLength: 0)
                    }
                default:
                    Image(systemName: sound.sfSymbol ?? "waveform").font(.title2)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(sound.title)
        } else {
            Image(systemName: "waveform.badge.plus")
                .accessibilityLabel("Configure widget")
        }
    }
}
#endif

#if os(iOS) && !targetEnvironment(macCatalyst) && compiler(>=6.0)
@available(iOSApplicationExtension 18.0, *)
struct PlayRandomSoundControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.florisvandesande.AmbientSpace.random-sound") {
            ControlWidgetButton(action: PlayRandomSoundIntent()) {
                Label("Play a random sound", systemImage: "shuffle")
            }
        }
        .displayName("Play a random sound")
        .description("Starts a random AmbientSpace sound.")
    }
}

@available(iOSApplicationExtension 18.0, *)
struct PlaySoundControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: "com.florisvandesande.AmbientSpace.selected-sound",
            provider: PlaySoundControlValueProvider()
        ) { sound in
            ControlWidgetButton(action: PlaySoundIntent(sound: sound)) {
                Label(sound.title, systemImage: sound.sfSymbol ?? "waveform")
            }
        }
        .displayName("Play sound")
        .description("Starts or pauses a selected AmbientSpace sound.")
    }
}

@available(iOSApplicationExtension 18.0, *)
struct PlaySoundControlValueProvider: AppIntentControlValueProvider {
    typealias Value = AmbientSoundEntity
    typealias Configuration = SelectSoundControlIntent

    func previewValue(configuration: SelectSoundControlIntent) -> AmbientSoundEntity {
        AmbientSoundEntity(
            id: "preview",
            title: "AmbientSpace",
            subtitle: String(localized: "Sound"),
            sfSymbol: "waveform",
            colorStart: "#29334C",
            colorEnd: "#594075"
        )
    }

    func currentValue(configuration: SelectSoundControlIntent) async throws -> AmbientSoundEntity {
        configuration.sound ?? previewValue(configuration: configuration)
    }
}
#endif
