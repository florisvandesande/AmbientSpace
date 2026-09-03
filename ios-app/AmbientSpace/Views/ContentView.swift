import SwiftUI

struct ContentView: View {
    @ObservedObject var playback: AudioPlaybackController
    @ObservedObject private var sleepTimer: SleepTimerController
    @State private var expandedTrackID: AudioTrack.ID?
    @State private var showsVolumePopover = false
    @State private var showsTimerPopover = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    init(playback: AudioPlaybackController) {
        self.playback = playback
        self.sleepTimer = playback.sleepTimer
    }

    var body: some View {
        ZStack {
            AmbientBackground(track: playback.currentTrack, isPlaying: playback.isPlaying)

            ScrollView {
                LazyVStack(spacing: 14) {
                    header
                        .padding(.bottom, 10)

                    if playback.tracks.isEmpty {
                        EmptyCatalogView()
                            .padding(.top, 48)
                    } else {
                        ForEach(playback.tracks) { track in
                            TrackRowView(
                                track: track,
                                isPlaying: playback.isPlaying && playback.currentTrack?.id == track.id,
                                isExpanded: expandedTrackID == track.id,
                                onToggleExpanded: {
                                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.35)) {
                                        expandedTrackID = expandedTrackID == track.id ? nil : track.id
                                    }
                                },
                                onTogglePlayback: {
                                    playback.togglePlayback(for: track)
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
        }
        .alert(
            "AmbientSpace cannot continue",
            isPresented: Binding(
                get: { playback.errorMessage != nil },
                set: { if !$0 { playback.dismissError() } }
            ),
            actions: {
                Button("Close") {
                    playback.dismissError()
                }
            },
            message: {
                Text(playback.errorMessage ?? String(localized: "Unknown error"))
            }
        )
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { sleepTimer.refresh() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AmbientSpace")
                .font(.largeTitle.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            HStack(alignment: .center, spacing: 12) {
                Text(playback.isPlaying ? String(localized: "Now playing: \(playback.currentTrack?.displayTitle ?? "")") : String(localized: "Choose an atmosphere"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer(minLength: 8)

                Button {
                    showsTimerPopover = false
                    showsVolumePopover.toggle()
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(HeaderControlButtonStyle())
                .accessibilityLabel("Volume and audio mode")
                .accessibilityIdentifier("volumeButton")
                .bottomPopover(isPresented: $showsVolumePopover) {
                    VolumePopoverView(playback: playback)
                }

                Button {
                    showsVolumePopover = false
                    showsTimerPopover.toggle()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: sleepTimer.isActive ? "moon.fill" : "moon")
                            .frame(width: 44, height: 44)
                        if sleepTimer.isActive {
                            Circle()
                                .fill(.orange)
                                .frame(width: 8, height: 8)
                                .offset(x: -4, y: 4)
                        }
                    }
                }
                .buttonStyle(HeaderControlButtonStyle())
                .accessibilityLabel("Sleep timer")
                .accessibilityIdentifier("timerButton")
                .bottomPopover(isPresented: $showsTimerPopover) {
                    SleepTimerPopoverView(
                        timer: playback.sleepTimer,
                        canStart: playback.isPlaying
                    )
                }
            }
        }
        .foregroundStyle(.primary)
    }
}

private struct HeaderControlButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .background(.regularMaterial, in: Circle())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct AmbientBackground: View {
    let track: AudioTrack?
    let isPlaying: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let firstColor = track?.startColor ?? Color(red: 0.16, green: 0.20, blue: 0.30)
        let secondColor = track?.endColor ?? Color(red: 0.35, green: 0.25, blue: 0.46)

        LinearGradient(
            colors: [
                colorScheme == .dark ? Color.black : Color.white,
                firstColor.opacity(isPlaying ? 0.32 : 0.16),
                secondColor.opacity(isPlaying ? 0.40 : 0.20),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            if !reduceTransparency {
                Circle()
                    .fill(firstColor.opacity(isPlaying ? 0.22 : 0.10))
                    .frame(width: 360, height: 360)
                    .blur(radius: 80)
                    .offset(x: 150, y: -230)
            }
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.2), value: track?.id)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: isPlaying)
    }
}

private struct EmptyCatalogView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.badge.plus")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(.secondary)
            Text("No sounds yet")
                .font(.title2.weight(.semibold))
            Text("Add a sound folder to audio-files and rebuild the app. The README in that folder explains each file step by step.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
