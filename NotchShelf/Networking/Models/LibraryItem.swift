import Foundation

struct Library: Decodable, Identifiable {
    let id: String
    let name: String
    let mediaType: String?
}

struct LibrariesResponse: Decodable {
    let libraries: [Library]
}

struct LibraryItemsResponse: Decodable {
    let results: [LibraryItem]
}

struct LibraryItem: Decodable, Identifiable {
    let id: String
    let libraryId: String?
    let mediaType: String?
    let media: Media?

    struct Media: Decodable {
        let metadata: Metadata?
        let tracks: [AudioTrack]?

        struct Metadata: Decodable {
            let title: String?
            let authorName: String?
        }
    }
}

struct Book: Identifiable {
    let item: LibraryItem

    var id: String { item.id }
    var title: String { item.media?.metadata?.title ?? L("Bilinmeyen başlık") }
    var author: String { item.media?.metadata?.authorName ?? L("Bilinmeyen yazar") }
}
