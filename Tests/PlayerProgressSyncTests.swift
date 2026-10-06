import XCTest

@MainActor
final class PlayerProgressSyncTests: XCTestCase {
    private var client: AudiobookshelfClient!
    private var player: PlayerViewModel!
    private var savedNotify: Any?
    private let book = Book(item: Fixture.firstItem)

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        // Test sürecinde bildirim izin dialogu açılmasın; kullanıcı ayarını geri koy.
        savedNotify = UserDefaults.standard.object(forKey: Preferences.Key.notifyOnFinish)
        UserDefaults.standard.set(false, forKey: Preferences.Key.notifyOnFinish)
        MockURLProtocol.stub(method: "POST", path: Endpoints.play("it1"), json: Fixture.playSession)
        MockURLProtocol.stub(method: "GET", path: Endpoints.cover("it1"), status: 404, json: "{}")
        MockURLProtocol.stub(method: "PATCH", path: Endpoints.progress("it1"), json: "{}")
        MockURLProtocol.stub(method: "POST", path: Endpoints.sessionClose("ses1"), json: "{}")

        client = AudiobookshelfClient(
            baseURL: Fixture.baseURL,
            token: "tok-123",
            sessionConfiguration: MockURLProtocol.configuration()
        )
        player = PlayerViewModel()
    }

    override func tearDown() {
        player = nil
        client = nil
        MockURLProtocol.reset()
        if let savedNotify {
            UserDefaults.standard.set(savedNotify, forKey: Preferences.Key.notifyOnFinish)
        } else {
            UserDefaults.standard.removeObject(forKey: Preferences.Key.notifyOnFinish)
        }
        super.tearDown()
    }

    private func sentProgress() throws -> ProgressUpdate? {
        guard let request = MockURLProtocol.recorded(method: "PATCH").last,
              let data = MockURLProtocol.body(of: request) else { return nil }
        return try JSONDecoder().decode(ProgressUpdate.self, from: data)
    }

    func testPlayOpensSessionAndResumesStoredPosition() async throws {
        await player.play(book: book, client: client, baseURL: Fixture.baseURL)

        XCTAssertEqual(player.title, "Dune")
        XCTAssertEqual(player.author, "Frank Herbert")
        XCTAssertEqual(player.duration, 3600, accuracy: 0.001)
        XCTAssertEqual(player.currentTime, 900, accuracy: 0.001, "kaldığın yerden devam etmeli")
        XCTAssertEqual(player.syncContext?.sessionId, "ses1")
        XCTAssertEqual(player.syncContext?.itemId, "it1")
        XCTAssertEqual(player.currentBook?.id, "it1")
        XCTAssertNil(player.lastError)
        XCTAssertEqual(MockURLProtocol.recorded(method: "POST", path: Endpoints.play("it1")).count, 1)
    }

    func testFailedSessionLeavesStateEmpty() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.stub(method: "POST", path: Endpoints.play("it1"), status: 500, json: "{}")
        await player.play(book: book, client: client, baseURL: Fixture.baseURL)

        XCTAssertNil(player.syncContext)
        XCTAssertNil(player.currentBook)
        XCTAssertNotNil(player.lastError)
    }

    func testSyncSendsCurrentRatio() async throws {
        await player.play(book: book, client: client, baseURL: Fixture.baseURL)
        player.currentTime = 1200
        await player.syncNow(finished: false)

        let update = try XCTUnwrap(sentProgress())
        XCTAssertEqual(update.currentTime, 1200, accuracy: 0.001)
        XCTAssertEqual(update.duration, 3600, accuracy: 0.001)
        XCTAssertEqual(update.progress, 1200 / 3600, accuracy: 0.0001)
        XCTAssertEqual(update.isFinished, false)
        XCTAssertNotNil(player.lastSyncAt)
    }

    func testSameSecondIsNotSentTwice() async throws {
        await player.play(book: book, client: client, baseURL: Fixture.baseURL)
        player.currentTime = 1200
        await player.syncNow(finished: false)
        await player.syncNow(finished: false)

        XCTAssertEqual(MockURLProtocol.recorded(method: "PATCH").count, 1)
    }

    func testFinishedBypassesDeduplication() async throws {
        await player.play(book: book, client: client, baseURL: Fixture.baseURL)
        player.currentTime = 1200
        await player.syncNow(finished: false)
        await player.syncNow(finished: true)

        XCTAssertEqual(MockURLProtocol.recorded(method: "PATCH").count, 2)
        XCTAssertEqual(try XCTUnwrap(sentProgress()).isFinished, true)
    }

    func testSyncIsNoopWithoutSession() async throws {
        player.duration = 1000
        player.currentTime = 500
        await player.syncNow(finished: true)

        XCTAssertTrue(MockURLProtocol.recorded(method: "PATCH").isEmpty)
    }

    func testStopFlushesFinalPositionThenClosesSession() async throws {
        await player.play(book: book, client: client, baseURL: Fixture.baseURL)
        player.currentTime = 1500
        player.stop()

        await waitUntil {
            MockURLProtocol.recorded(method: "PATCH").count == 1
                && MockURLProtocol.recorded(method: "POST", path: Endpoints.sessionClose("ses1")).count == 1
        }
        let update = try XCTUnwrap(sentProgress())
        XCTAssertEqual(update.currentTime, 1500, accuracy: 0.001)
        XCTAssertEqual(update.isFinished, false)
        XCTAssertNil(player.syncContext)
        XCTAssertEqual(player.currentTime, 0)
        XCTAssertEqual(player.isPlaying, false)
    }
}
