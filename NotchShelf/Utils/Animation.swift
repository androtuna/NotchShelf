import SwiftUI

// Spec §7/§4 animasyon preset'leri.
enum AppAnimation {
    /// Varsayılan arayüz geçişleri.
    static let standard = Animation.spring(response: 0.35, dampingFraction: 0.8)
    /// Notch HUD aç/kapa.
    static let hud = Animation.spring(response: 0.4, dampingFraction: 0.75)
    /// Küçük durum değişimleri (toggle, rozet).
    static let quick = Animation.spring(response: 0.22, dampingFraction: 0.85)

    // AppKit tarafı (NSAnimationContext) için aynı eğriler.
    static let hudDuration = 0.4
    static let standardDuration = 0.35
}
