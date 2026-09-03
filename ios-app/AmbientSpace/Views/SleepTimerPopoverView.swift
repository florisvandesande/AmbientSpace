import SwiftUI

struct SleepTimerPopoverView: View {
    @ObservedObject var timer: SleepTimerController
    let canStart: Bool

    @State private var customHours = 1
    @State private var customMinutes = 0

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Sleep timer", systemImage: "moon.fill")
                .font(.headline)

            if timer.isActive {
                activeTimer
            } else {
                timerOptions
            }
        }
        .padding(20)
        .background(.regularMaterial)
    }

    private var activeTimer: some View {
        VStack(spacing: 16) {
            Text(formattedRemainingTime)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Time remaining: \(formattedRemainingTime)")

            Text("The sound fades out during the last fifteen seconds.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Cancel sleep timer", role: .destructive) {
                timer.cancel()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
        }
    }

    private var timerOptions: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach([15, 30, 45, 60], id: \.self) { minutes in
                    Button("\(minutes) min") {
                        timer.start(duration: TimeInterval(minutes * 60))
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(!canStart)
                }
            }

            Divider()

            Text("Custom duration")
                .font(.subheadline.weight(.semibold))

            HStack {
                Picker("Hours", selection: $customHours) {
                    ForEach(0...12, id: \.self) { hour in
                        Text("\(hour) h").tag(hour)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: customHours) { _, hours in
                    if hours == 12 { customMinutes = 0 }
                }

                Picker("Minutes", selection: $customMinutes) {
                    ForEach(0..<(customHours == 12 ? 1 : 60), id: \.self) { minute in
                        Text("\(minute) min").tag(minute)
                    }
                }
                .pickerStyle(.menu)
            }

            Button("Start custom timer") {
                let totalMinutes = min(max((customHours * 60) + customMinutes, 1), 720)
                timer.start(duration: TimeInterval(totalMinutes * 60))
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .disabled(!canStart || (customHours == 0 && customMinutes == 0))

            if !canStart {
                Text("Play a sound before setting the sleep timer.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var formattedRemainingTime: String {
        let totalSeconds = max(Int(timer.remainingSeconds.rounded(.up)), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
