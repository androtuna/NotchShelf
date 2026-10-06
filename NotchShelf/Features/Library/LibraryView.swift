import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var server: ServerViewModel
    @EnvironmentObject var rootState: RootView.State
    @EnvironmentObject var player: PlayerViewModel
    @StateObject private var vm = LibraryViewModel()

    var body: some View {
        Group {
            if !server.isConnected {
                notConnected
            } else {
                content
            }
        }
        .task(id: server.status) { await vm.refreshIfNeeded(server: server) }
        .onChange(of: server.isConnected) { _, connected in
            if !connected { vm.reset() }
        }
    }

    private var notConnected: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "externaldrive.badge.questionmark")
                .font(.system(size: 28)).foregroundStyle(Theme.gradient)
            Text("Sunucuya bağlı değil")
                .font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
            Text("Kitaplarını görmek için önce bir Audiobookshelf sunucusuna bağlan.")
                .font(.system(size: 11)).foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            Button {
                rootState.selectedTab = .servers
            } label: {
                Text("Sunucuya bağlan")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 9)
                    .background(Capsule().fill(Theme.gradient))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    private var content: some View {
        VStack(spacing: 0) {
            libraryPicker
            Divider().overlay(Theme.cardBorder)
            if vm.isLoading && vm.items.isEmpty {
                Spacer()
                ProgressView().tint(Theme.violet)
                Spacer()
            } else if let error = vm.error {
                errorView(error)
            } else if vm.items.isEmpty {
                emptyView
            } else {
                bookList
            }
        }
    }

    private var libraryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(vm.libraries) { lib in
                    let selected = vm.selectedLibraryId == lib.id
                    Button {
                        Task {
                            if let client = server.client {
                                await vm.select(libraryId: lib.id, client: client)
                            }
                        }
                    } label: {
                        Text(lib.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(selected ? Theme.ink : Theme.muted)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(selected ? Theme.cardFill : .clear))
                            .overlay(Capsule().stroke(selected ? Theme.cardBorder : .clear))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .scrollIndicators(.hidden)
    }

    private var bookList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(vm.items) { item in
                    BookRowView(
                        item: item,
                        client: server.client,
                        isCurrent: player.currentBook?.id == item.id
                    )
                    .onTapGesture { play(item) }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("Bu kütüphanede kitap yok").font(.system(size: 12)).foregroundStyle(Theme.muted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "exclamationmark.triangle").foregroundStyle(Theme.pink).font(.system(size: 22))
            Text(message).font(.system(size: 11)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            Button("Yeniden dene") {
                Task { if let c = server.client { await vm.loadLibraries(client: c) } }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.ink)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    private func play(_ item: LibraryItem) {
        guard let client = server.client, let baseURL = server.baseURL else { return }
        let book = Book(item: item)
        rootState.selectedTab = .player
        Task { await player.play(book: book, client: client, baseURL: baseURL) }
    }
}
