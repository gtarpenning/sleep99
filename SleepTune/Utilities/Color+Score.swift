import SwiftUI

extension Color {
    static func scoreColor(for score: Double) -> Color {
        DS.scoreColor(for: score)
    }

    // Named differently from any SDK initializer to avoid conflicts
    static func fromHex(_ value: String) -> Color {
        var h = value.trimmingCharacters(in: .whitespacesAndNewlines)
        h = h.hasPrefix("#") ? String(h.dropFirst()) : h
        let scanner = Scanner(string: h)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        return Color(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8)  & 0xFF) / 255,
            blue:  Double(rgb         & 0xFF) / 255
        )
    }
}
