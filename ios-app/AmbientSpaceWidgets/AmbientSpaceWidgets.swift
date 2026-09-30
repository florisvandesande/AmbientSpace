import ActivityKit
import SwiftUI
import WidgetKit

@main
struct AmbientSpaceWidgets: WidgetBundle {
    var body: some Widget {
        AmbientPlaybackLiveActivity()
        #if compiler(>=6.0)
        if #available(iOSApplicationExtension 18.0, *) {
            PlayRandomSoundControl()
            PlaySoundControl()
        }
        #endif
    }
}

struct AmbientPlaybackLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AmbientPlaybackActivityAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: context.state.sfSymbol ?? "waveform")
                    .font(.title2)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.title).font(.headline)
                    Text(context.state.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                    Image(systemName: context.state.sfSymbol ?? "waveform")
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title).font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

#if compiler(>=6.0)
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
                Label(sound.title, systemImage: sound.sfSymbol ?? "play.fill")
            }
        }
        .displayName("Play sound")
        .description("Starts a selected AmbientSpace sound.")
    }
}

@available(iOSApplicationExtension 18.0, *)
struct PlaySoundControlValueProvider: AppIntentControlValueProvider {
    typealias Value = AmbientSoundEntity
    typealias Configuration = SelectSoundControlIntent

    func previewValue(configuration: SelectSoundControlIntent) -> AmbientSoundEntity {
        AmbientSoundEntity(id: "preview", title: "AmbientSpace", subtitle: "Sound", sfSymbol: nil)
    }

    func currentValue(configuration: SelectSoundControlIntent) async throws -> AmbientSoundEntity {
        configuration.sound ?? previewValue(configuration: configuration)
    }
}
#endif
