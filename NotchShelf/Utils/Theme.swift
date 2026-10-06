import SwiftUI

// Spec §7 renk paleti. Tüm arayüz buradan okur.
enum Theme {
    static let base = Color(hex: 0x0A0815)
    static let ink = Color(hex: 0xF6F3FF)
    static let muted = Color(hex: 0xA79FC4)
    static let violet = Color(hex: 0xA855F7)
    static let magenta = Color(hex: 0xD946EF)
    static let pink = Color(hex: 0xFF375F)
    static let orange = Color(hex: 0xFF8A3C)

    /// linear-gradient(100deg, violet, magenta, orange)
    static let gradient = LinearGradient(
        stops: [
            .init(color: violet, location: 0.0),
            .init(color: magenta, location: 0.55),
            .init(color: orange, location: 1.0),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Koyu zeminde tek yönlü ince ışık çizgisi (kart/HUD kenarı).
    static let edgeHighlight = LinearGradient(
        colors: [Color.white.opacity(0.14), Color.white.opacity(0.03)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let cardFill = Color.white.opacity(0.035)
    static let cardBorder = Color.white.opacity(0.08)
}

enum Metrics {
    static let cardRadius: CGFloat = 16
    static let controlRadius: CGFloat = 13
    static let popoverWidth: CGFloat = 380
    static let popoverHeight: CGFloat = 520
    static let contentPadding: CGFloat = 20
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
