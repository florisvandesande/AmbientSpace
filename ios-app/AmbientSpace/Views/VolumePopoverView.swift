import SwiftUI

struct VolumePopoverView: View {
    @ObservedObject var playback: AudioPlaybackController

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Volume", systemImage: "speaker.wave.2.fill")
                .font(.headline)

            HStack {
                Slider(value: Binding(
                    get: { playback.outputVolume },
                    set: { playback.setOutputVolume($0) }
                ), in: 0...1, step: 0.01)
                .accessibilityLabel("AmbientSpace volume")
                .accessibilityValue(playback.outputVolume.formatted(.percent.precision(.fractionLength(0))))
                .accessibilityIdentifier("appVolumeSlider")

                Text(playback.outputVolume, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
                    .font(.subheadline)
                    .frame(minWidth: 44, alignment: .trailing)
                    .accessibilityHidden(true)
            }

            Text("Only changes AmbientSpace. The iPhone volume and other apps stay unchanged.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Toggle(
                    "Foreground mode",
                    isOn: Binding(
                        get: { playback.audioMode == .foreground },
                        set: { enabled in
                            playback.setAudioMode(enabled ? .foreground : .background)
                        }
                    )
                )
                .font(.body.weight(.semibold))

                Text(
                    playback.audioMode == .background
                        ? String(localized: "AmbientSpace mixes with other apps and leaves their media controls available.")
                        : String(localized: "AmbientSpace takes over media controls and shows the current cover.")
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
    }
}
