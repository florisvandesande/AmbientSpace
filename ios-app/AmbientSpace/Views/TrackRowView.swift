import SwiftUI
import UIKit

struct TrackRowView: View {
    let track: AudioTrack
    let isPlaying: Bool
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onTogglePlayback: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var gradient: TrackGradient { track.rowGradient(isPlaying: isPlaying) }
    private var idleIconName: String {
        guard let symbol = track.displaySFSymbol, UIImage(systemName: symbol) != nil else {
            return "play.fill"
        }
        return symbol
    }

    func toggleBoth() {
        onTogglePlayback()
        onToggleExpanded()
    }

    var body: some View {
        Button(action: toggleBoth) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.displayTitle)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        Text(track.displaySubtitle)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Clip only the reveal area: moving text cannot cross the subtitle.
                    VStack(alignment: .leading, spacing: 8) {
                        if isExpanded {
                            Text(track.displayDescription)
                                .accessibilityIdentifier("trackDescription-\(track.id)")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.90))
                                .multilineTextAlignment(.leading)
                                .lineSpacing(3)
                                .padding(.top, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
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

                HStack(spacing: 0) {
                    Image(systemName: isPlaying ? "pause.fill" : idleIconName)
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
        }
        // The whole row is now tappable for playback - no nested play button wrapper
        .padding(18)
        .background {
            LinearGradient(
                colors: [Color(components: gradient.start), Color(components: gradient.end)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(isPlaying ? 0.30 : 0.12), lineWidth: 0.75)
        }
        .shadow(color: track.endColor.opacity(isPlaying ? 0.28 : 0.08), radius: 18, y: 8)
        // Keep the play icon state visible while playing as a second indication
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: isPlaying)
    }
}
