import SwiftUI

struct TrackRowView: View {
    let track: AudioTrack
    let isPlaying: Bool
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onTogglePlayback: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var gradient: TrackGradient { track.rowGradient(isPlaying: isPlaying) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: onToggleExpanded) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.displayTitle)
                            .font(.title3.weight(.bold))
                        Text(track.displaySubtitle)
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(track.displayTitle), \(track.displaySubtitle)")
                .accessibilityHint(isExpanded ? String(localized: "Hide description") : String(localized: "Show description"))
                .accessibilityValue(isExpanded ? String(localized: "Expanded") : String(localized: "Collapsed"))
                .accessibilityIdentifier("trackTitle-\(track.id)")

                // Clip only the reveal area: moving text cannot cross the subtitle.
                VStack(alignment: .leading, spacing: 0) {
                    if isExpanded {
                        Text(track.displayDescription)
                            .accessibilityIdentifier("trackDescription-\(track.id)")
                            .font(.body)
                            .lineSpacing(3)
                            .padding(.top, 10)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(
                                reduceMotion
                                    ? .opacity
                                    : .opacity.combined(with: .move(edge: .top))
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
            }

            Button(action: onTogglePlayback) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay {
                        Circle().strokeBorder(.white.opacity(0.28), lineWidth: 0.5)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? String(localized: "Pause \(track.displayTitle)") : String(localized: "Play \(track.displayTitle)"))
            .accessibilityIdentifier("trackPlayback-\(track.id)")
        }
        .foregroundStyle(.white)
        .padding(18)
        .background {
            LinearGradient(
                colors: [Color(components: gradient.start), Color(components: gradient.end)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(isPlaying ? 0.30 : 0.12), lineWidth: 0.75)
        }
        .shadow(color: track.endColor.opacity(isPlaying ? 0.28 : 0.08), radius: 18, y: 8)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: isPlaying)
    }
}
