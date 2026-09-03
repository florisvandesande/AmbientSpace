import SwiftUI

extension Color {
    init?(hex: String) {
        guard let components = RGBComponents(hex: hex) else {
            return nil
        }
        self.init(components: components)
    }

    init(components: RGBComponents) {
        self.init(.sRGB, red: components.red, green: components.green, blue: components.blue, opacity: 1)
    }
}

extension AudioTrack {
    func rowGradient(isPlaying: Bool) -> TrackGradient {
        TrackGradient(
            start: RGBComponents(hex: colorStart) ?? RGBComponents(red: 0.25, green: 0.2, blue: 0.65),
            end: RGBComponents(hex: colorEnd) ?? RGBComponents(red: 0.1, green: 0.3, blue: 0.8),
            isPlaying: isPlaying
        )
    }

    var startColor: Color {
        Color(hex: colorStart) ?? Color.indigo
    }

    var endColor: Color {
        Color(hex: colorEnd) ?? Color.blue
    }
}
