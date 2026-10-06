import AVFoundation
import AppKit
import Combine
import Foundation

@MainActor
final class PlayerViewModel: ObservableObject {
    static let shared = PlayerViewModel()

    @Published var currentBook: Book?
    @Published var title = ""
    @Published var author = ""
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var playbackRate: Float = 1.0
    @Published var volume: Float = 0.8
    @Published var lastError: String?
    // UI "kaydedildi" göstergesi için.
    @Published private(set) var lastSyncAt: Date?
    @Published private(set) var isSyncing = false

    struct SyncContext {
        let client: AudiobookshelfClient
        let itemId: String
        let sessionId: String
    }

    // Adım 7: progress sync bu bağlamı kullanır.
    private(set) var syncContext: SyncContext?

    private var player: AVQueuePlayer?
    private var timeObserver: Any?
    private var statusCancellable: AnyCancellable?
    private var endCancellable: AnyCancellable?
    private var syncTimer: Timer?
    private var lastSyncedTime: Double = -1
    private let nowPlaying = NowPlayingController()
    // Kitap bittiğinde kuyruk boşalır; aynı parçalardan yeniden kuyruk kurabilmek
    // için adresleri tutuyoruz.
    private var trackURLs: [URL] = []
    private var inFlightSync: Task<Void, Never>?
    private var syncGeneration = 0

    // internal: testler paylaşılan tek örnek yerine izole örnek kurabilsin.
    init() {}

    // MARK: - Başlatma

    func play(book: Book, client: AudiobookshelfClient, baseURL: URL) async {
        stopInternal(closeSession: true)
        do {
            let session = try await client.startPlaybackSession(itemId: book.id)
            syncContext = SyncContext(client: client, itemId: book.id, sessionId: session.id)
            currentBook = book
            title = book.title
            author = book.author
            duration = session.duration ?? 0

            let urls = session.audioTracks.compactMap { track -> URL? in
                guard let path = track.contentUrl else { return nil }
                return Self.absoluteURL(path, baseURL: baseURL)
            }
            guard !urls.isEmpty else {
                lastError = L("Çalınabilir parça bulunamadı")
                return
            }
            trackURLs = urls
            let items = urls.map { AVPlayerItem(url: $0) }
            let player = AVQueuePlayer(items: items)
            configure(player: player)
            player.rate = playbackRate

            // Kaldığımız yerden devam et (tek parçalı akışta global seek).
            let resume = session.resumeTime
            if resume > 1, urls.count == 1 {
                currentTime = min(resume, duration > 0 ? duration : resume)
                player.seek(
                    to: CMTime(seconds: currentTime, preferredTimescale: 600),
                    toleranceBefore: .zero,
                    toleranceAfter: .zero,
                    completionHandler: { _ in }
                )
            }
            startSyncLoop()

            if let cover = try? await client.coverData(itemId: book.id) {
                nowPlaying.artworkImage = NSImage(data: cover)
            }
            updateNowPlaying()
        } catch {
            lastError = LF("Oturum açılamadı: %@", String(describing: error))
        }
    }

    private func configure(player: AVQueuePlayer) {
        self.player = player
        player.volume = volume
        nowPlaying.setupCommands(self)

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.duration == 0, let itemDuration = self.player?.currentItem?.duration,
                   itemDuration.isNumeric, !itemDuration.seconds.isNaN, itemDuration.seconds > 0 {
                    self.duration = itemDuration.seconds
                }
                self.currentTime = min(CMTimeGetSeconds(time), self.duration > 0 ? self.duration : CMTimeGetSeconds(time))
                self.updateNowPlaying()
            }
        }

        statusCancellable = player
            .publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                self.isPlaying = status == .playing
                self.updateNowPlaying()
            }

        endCancellable = NotificationCenter.default
            .publisher(for: .AVPlayerItemDidPlayToEndTime)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, let player = self.player else { return }
                if player.items().isEmpty {
                    self.currentTime = self.duration
                    Task { await self.syncNow(finished: true) }
                    self.updateNowPlaying()
                }
            }
    }

    nonisolated static func absoluteURL(_ path: String, baseURL: URL) -> URL? {
        if let url = URL(string: path), url.scheme != nil { return url }
        return URL(string: baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + path)
    }

    // MARK: - Progress sync (Adım 7)

    private func startSyncLoop() {
        syncTimer?.invalidate()
        lastSyncedTime = -1
        // Timer, Preferences'tan okunan aralıkla değil 1 sn'de bir tetiklenir;
        // böylece ayar değiştiği anda (yeni aralık) geçerli olur.
        syncTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isPlaying, self.syncContext != nil else { return }
                let due = Date().timeIntervalSince(self.lastSyncAt ?? .distantPast)
                guard due >= Preferences.syncInterval else { return }
                Task { await self.syncNow(finished: false) }
            }
        }
    }

    func syncNow(finished: Bool) async {
        guard let context = syncContext else { return }
        guard duration > 0, currentTime > 0 || finished else { return }
        // Aynı saniyeyi tekrar gönderme (finished her zaman geçer).
        if !finished, abs(currentTime - lastSyncedTime) < 1 { return }

        if let inFlight = inFlightSync {
            // Periyodik tur bir sonraki saniyede yeniden dener; kitap bitti
            // işaretini düşürmemek için uçuştaki isteği bekliyoruz.
            guard finished else { return }
            await inFlight.value
            guard !isSyncing, syncContext != nil else { return }
        }
        // Task bir struct olduğu için kimlik karşılaştırması nesne olarak yapılamaz;
        // hangi turun handle'ı tuttuğumu sayaçla izliyoruz.
        syncGeneration += 1
        let generation = syncGeneration
        let task = Task { await self.performSync(context: context, finished: finished) }
        inFlightSync = task
        await task.value
        if generation == syncGeneration { inFlightSync = nil }
    }

    private func performSync(context: SyncContext, finished: Bool) async {
        isSyncing = true
        defer { isSyncing = false }
        let time = currentTime
        let total = duration
        do {
            try await context.client.updateProgress(
                itemId: context.itemId,
                currentTime: time,
                duration: total,
                finished: finished
            )
            lastSyncedTime = time
            lastSyncAt = Date()
            NSLog("NotchShelf: progress senkronlandı item=%@ time=%.0f finished=%d",
                  context.itemId, time, finished ? 1 : 0)
            if finished {
                let cover = try? await context.client.coverData(itemId: context.itemId)
                await NotificationService.shared.bookFinished(title: title, coverData: cover)
            }
        } catch {
            // Sonraki tur normal aralıkta yeniden dener; UI'ı kirletme.
            NSLog("NotchShelf: progress senkron başarısız: %@", String(describing: error))
        }
    }

    // MARK: - Kontroller

    func togglePlay() { isPlaying ? pause() : play() }

    func play() {
        guard let player else { return }
        if player.currentItem == nil {
            // Kuyruk bitti (kitap sonu): başa sar, aksi halde kalınan yerden devam.
            if duration > 0, currentTime >= duration - 1 { currentTime = 0 }
            seek(to: currentTime)
        }
        if player.rate == 0 { player.rate = playbackRate }
    }

    func pause() {
        player?.pause()
        Task { await syncNow(finished: false) }
    }

    func skip(_ seconds: Double) {
        seek(to: currentTime + seconds)
    }

    func seek(to time: Double) {
        guard let player else { return }
        reloadExhaustedQueue(player)
        let upper = duration > 0 ? duration : time
        let clamped = max(0, min(time, upper))
        currentTime = clamped
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600),
                    toleranceBefore: .zero,
                    toleranceAfter: .zero)
        updateNowPlaying()
    }

    // AVQueuePlayer son parçayı bitirince kuyruğu boşaltır; currentItem nil
    // olduğunda seek/play sessizce etkisiz kalır. Aynı adreslerle kuyruğu
    // yeniden kurup istenen konuma sarıyoruz.
    private func reloadExhaustedQueue(_ player: AVQueuePlayer) {
        guard player.currentItem == nil, !trackURLs.isEmpty else { return }
        player.removeAllItems()
        for url in trackURLs {
            player.insert(AVPlayerItem(url: url), after: nil)
        }
        NSLog("NotchShelf: kuyruk yeniden kuruldu (%d parça)", trackURLs.count)
    }

    func setRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying { player?.rate = rate }
        updateNowPlaying()
    }

    func setVolume(_ value: Float) {
        volume = value
        player?.volume = value
    }

    func stop() {
        stopInternal(closeSession: true)
    }

    private func stopInternal(closeSession: Bool) {
        syncTimer?.invalidate()
        syncTimer = nil
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        statusCancellable = nil
        endCancellable = nil
        player?.pause()
        player = nil
        trackURLs = []

        // Son konumu oturum kapanmadan önce bildir.
        let context = syncContext
        let finalTime = currentTime
        let finalDuration = duration
        syncContext = nil
        isPlaying = false
        currentTime = 0
        nowPlaying.clear()
        if let context, finalDuration > 0, finalTime > 0 {
            Task {
                try? await context.client.updateProgress(
                    itemId: context.itemId,
                    currentTime: finalTime,
                    duration: finalDuration,
                    finished: false
                )
            }
        }
        if closeSession, let context {
            Task {
                try? await context.client.closePlaybackSession(sessionId: context.sessionId)
            }
        }
    }

    private func updateNowPlaying() {
        guard !title.isEmpty else { return }
        nowPlaying.update(
            title: title,
            author: author,
            duration: duration,
            elapsed: currentTime,
            rate: playbackRate,
            playing: isPlaying
        )
    }
}
