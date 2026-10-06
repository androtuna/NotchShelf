enum Endpoints {
    static let login = "/login"
    static let libraries = "/api/libraries"
    static let me = "/api/me"

    static func libraryItems(_ libraryId: String) -> String { "/api/libraries/\(libraryId)/items" }
    static func item(_ id: String) -> String { "/api/items/\(id)" }
    static func cover(_ id: String) -> String { "/api/items/\(id)/cover" }
    static func play(_ itemId: String) -> String { "/api/items/\(itemId)/play" }
    static func sessionClose(_ sessionId: String) -> String { "/api/session/\(sessionId)/close" }
    static func progress(_ itemId: String) -> String { "/api/me/progress/\(itemId)" }
    static func sessionSync(_ itemId: String, _ sessionId: String) -> String {
        "/api/items/\(itemId)/play/\(sessionId)/sync"
    }
}
