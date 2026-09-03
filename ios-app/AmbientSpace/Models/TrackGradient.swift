struct RGBComponents: Equatable {
    let red: Double
    let green: Double
    let blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init?(hex: String) {
        guard hex.count == 7, hex.first == "#" else { return nil }
        let digits = hex.dropFirst()
        guard digits.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }),
              let integer = UInt64(digits, radix: 16) else { return nil }
        red = Double((integer >> 16) & 0xFF) / 255
        green = Double((integer >> 8) & 0xFF) / 255
        blue = Double(integer & 0xFF) / 255
    }

    func saturated(_ amount: Double) -> RGBComponents {
        if amount == 1 { return self }
        // Mix toward a neutral of equal encoded luma; no black/transparent layer.
        let gray = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return RGBComponents(
            red: gray + (red - gray) * amount,
            green: gray + (green - gray) * amount,
            blue: gray + (blue - gray) * amount
        )
    }
}

struct TrackGradient {
    let start: RGBComponents
    let end: RGBComponents

    init(start: RGBComponents, end: RGBComponents, isPlaying: Bool) {
        let saturation = isPlaying ? 1.0 : 0.5
        self.start = start.saturated(saturation)
        self.end = end.saturated(saturation)
    }
}
