import SwiftUI

// Kapak görselini ABS'den async yükler, bellekte önbelleğe alır.
struct CoverImage: View {
    let itemId: String
    let client: AudiobookshelfClient?
    var cornerRadius: CGFloat = 6

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Theme.cardFill
                    Image(systemName: "book.closed")
                        .foregroundStyle(Theme.muted.opacity(0.5))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(Theme.cardBorder))
        .task(id: itemId) { await load() }
    }

    private func load() async {
        if let cached = CoverCache.shared.image(for: itemId) {
            image = cached
            return
        }
        guard let client else { return }
        if let data = try? await client.coverData(itemId: itemId),
           let nsImage = NSImage(data: data) {
            CoverCache.shared.set(nsImage, for: itemId)
            image = nsImage
        }
    }
}

final class CoverCache {
    static let shared = CoverCache()
    private let cache = NSCache<NSString, NSImage>()
    private init() { cache.countLimit = 200 }
    func image(for key: String) -> NSImage? { cache.object(forKey: key as NSString) }
    func set(_ image: NSImage, for key: String) { cache.setObject(image, forKey: key as NSString) }
}
