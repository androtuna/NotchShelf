import Foundation
import Combine

// Kütüphaneler + seçili kütüphanenin kitapları. ServerViewModel'e bağımlı.
@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var libraries: [Library] = []
    @Published var selectedLibraryId: String?
    @Published var items: [LibraryItem] = []
    @Published var isLoading = false
    @Published var error: String?

    private var loadedForStatus = false

    func refreshIfNeeded(server: ServerViewModel) async {
        guard server.isConnected, let client = server.client else {
            libraries = []
            items = []
            return
        }
        if !libraries.isEmpty && loadedForStatus { return }
        await loadLibraries(client: client)
    }

    func loadLibraries(client: AudiobookshelfClient) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let libs = try await client.libraries()
            libraries = libs
            loadedForStatus = true
            if selectedLibraryId == nil {
                selectedLibraryId = libs.first?.id
            }
            if let id = selectedLibraryId {
                await loadItems(libraryId: id, client: client)
            }
        } catch {
            self.error = ServerViewModel.describe(error)
        }
    }

    func select(libraryId: String, client: AudiobookshelfClient) async {
        guard selectedLibraryId != libraryId else { return }
        selectedLibraryId = libraryId
        await loadItems(libraryId: libraryId, client: client)
    }

    func loadItems(libraryId: String, client: AudiobookshelfClient) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            items = try await client.items(in: libraryId)
        } catch {
            items = []
            self.error = ServerViewModel.describe(error)
        }
    }

    func reset() {
        libraries = []
        items = []
        selectedLibraryId = nil
        loadedForStatus = false
    }
}
