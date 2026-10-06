import Foundation

struct Progress: Decodable {
    let id: String?
    let currentTime: Double?
    let duration: Double?
    let progress: Double?
    let isFinished: Bool?
}

struct ProgressUpdate: Codable {
    let currentTime: Double
    let duration: Double
    let progress: Double
    let isFinished: Bool
}
