import Foundation

enum Formatters {
    /// 3725 -> "1:02:05", 125 -> "2:05"
    static func time(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    /// 6325 -> "1 sa 45 dk"
    static func durationLabel(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "—" }
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return LF("%d sa %d dk", h, m) }
        return LF("%d dk", m)
    }
}

extension Date {
    /// "şimdi", "12 sn önce", "2 dk önce"
    var relativeDescription: String {
        let seconds = Int(-timeIntervalSinceNow)
        switch seconds {
        case ..<5: return L("şimdi")
        case ..<60: return LF("%d sn önce", seconds)
        case ..<3600: return LF("%d dk önce", seconds / 60)
        default: return LF("%d sa önce", seconds / 3600)
        }
    }
}
