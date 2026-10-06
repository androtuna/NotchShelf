import Foundation

struct User: Decodable {
    let id: String
    let username: String
    let token: String?
    let mediaProgress: [Progress]?
}

struct LoginResponse: Decodable {
    let user: User
    let userDefaultLibraryId: String?
}

struct LoginRequest: Codable {
    let username: String
    let password: String
}
