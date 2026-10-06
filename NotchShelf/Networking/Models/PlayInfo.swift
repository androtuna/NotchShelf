import Foundation

// ABS'de çalma bilgisi, oturum açılarak alınır (POST /api/items/{id}/play).
struct PlaybackSession: Decodable {
    let id: String
    let itemId: String?
    let audioTracks: [AudioTrack]
    let chapters: [Chapter]?
    let duration: Double?
    // ABS oturumu kaldığımız yeri taşır; başlatınca oraya atlarız.
    let progress: Double?
    let currentTime: Double?
    let mediaProgress: MediaProgress?

    struct MediaProgress: Decodable {
        let currentTime: Double?
        let progress: Double?
        let isFinished: Bool?
    }

    var resumeTime: Double {
        if let currentTime, currentTime > 0 { return currentTime }
        if let p = mediaProgress?.currentTime, p > 0 { return p }
        if let progress, progress > 0, let duration, duration > 0 { return progress * duration }
        if let p = mediaProgress?.progress, p > 0, let duration, duration > 0 { return p * duration }
        return 0
    }
}

struct AudioTrack: Decodable {
    let index: Int?
    let title: String?
    let contentUrl: String?
    let duration: Double?
    let mimeType: String?
}

struct Chapter: Decodable {
    let id: String?
    let start: Double?
    let end: Double?
    let title: String?
}
