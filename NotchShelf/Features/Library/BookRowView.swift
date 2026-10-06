import SwiftUI

struct BookRowView: View {
    let item: LibraryItem
    let client: AudiobookshelfClient?
    var isCurrent: Bool = false

    private var book: Book { Book(item: item) }

    var body: some View {
        HStack(spacing: 12) {
            CoverImage(itemId: item.id, client: client, cornerRadius: 6)
                .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(book.author)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: isCurrent ? "waveform" : "play.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Theme.gradient)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(isCurrent ? Theme.cardFill : .clear))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(isCurrent ? Theme.cardBorder : .clear))
        .contentShape(Rectangle())
    }
}
