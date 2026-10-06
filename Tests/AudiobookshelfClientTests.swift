import XCTest

// NotchShelf kaynakları test hedefiyle aynı modülde derlenir; bu yüzden
// @testable import gerekmez ve internal tipler doğrudan görünür.
final class AudiobookshelfClientTests: XCTestCase {
    private var client: AudiobookshelfClient!

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        client = AudiobookshelfClient(
            baseURL: Fixture.baseURL,
            token: "tok-123",
            sessionConfiguration: MockURLProtocol.configuration()
        )
    }

    override func tearDown() {
        client = nil
        MockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - Okuma uçları

    func testLibrariesUnwrapsLibrariesKey() async throws {
        MockURLProtocol.stub(method: "GET", path: Endpoints.libraries, json: Fixture.libraries)
        let libraries = try await client.libraries()
        XCTAssertEqual(libraries.count, 1)
        XCTAssertEqual(libraries.first?.id, "lib1")
        XCTAssertEqual(libraries.first?.name, "Kitaplar")
    }

    func testItemsUnwrapsResultsKey() async throws {
        let path = Endpoints.libraryItems("lib1")
        MockURLProtocol.stub(method: "GET", path: path, json: Fixture.items)
        let items = try await client.items(in: "lib1")
        XCTAssertEqual(items.map(\.id), ["it1", "it2"])
    }

    func testAuthenticatedRequestsCarryBearerToken() async throws {
        MockURLProtocol.stub(method: "GET", path: Endpoints.me, json: Fixture.me)
        _ = try await client.me()
        let request = try XCTUnwrap(MockURLProtocol.recorded(method: "GET", path: Endpoints.me).first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer tok-123")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    func testMissingTokenThrowsBeforeAnyRequest() async {
        let anonymous = AudiobookshelfClient(
            baseURL: Fixture.baseURL,
            sessionConfiguration: MockURLProtocol.configuration()
        )
        do {
            _ = try await anonymous.libraries()
            XCTFail("missingToken beklenirken başarılı döndü")
        } catch let error as AudiobookshelfError {
            XCTAssertEqual(error, .missingToken)
        } catch {
            XCTFail("beklenmeyen hata: \(error)")
        }
        XCTAssertTrue(MockURLProtocol.recorded(method: "GET").isEmpty)
    }

    // MARK: - Oturum ve gövdeli istekler

    func testLoginStoresReturnedToken() async throws {
        MockURLProtocol.stub(method: "POST", path: Endpoints.login, status: 200, json: Fixture.login)
        let response = try await client.login(username: "tuna", password: "geheim")
        XCTAssertEqual(response.user.username, "tuna")
        XCTAssertEqual(response.userDefaultLibraryId, "lib1")

        let request = try XCTUnwrap(MockURLProtocol.recorded(method: "POST", path: Endpoints.login).first)
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"), "login token istemez")
        let body = try XCTUnwrap(MockURLProtocol.body(of: request))
        let decoded = try JSONDecoder().decode(LoginRequest.self, from: body)
        XCTAssertEqual(decoded.username, "tuna")
        XCTAssertEqual(decoded.password, "geheim")

        // Login sonrası token istemcide güncellenir.
        MockURLProtocol.stub(method: "GET", path: Endpoints.me, json: Fixture.me)
        _ = try await client.me()
        let meRequest = try XCTUnwrap(MockURLProtocol.recorded(method: "GET", path: Endpoints.me).first)
        XCTAssertEqual(meRequest.value(forHTTPHeaderField: "Authorization"), "Bearer tok-123")
    }

    func testStartPlaybackSessionParsesResumePoint() async throws {
        let path = Endpoints.play("it1")
        MockURLProtocol.stub(method: "POST", path: path, json: Fixture.playSession)
        let session = try await client.startPlaybackSession(itemId: "it1")
        XCTAssertEqual(session.id, "ses1")
        XCTAssertEqual(session.duration, 3600)
        XCTAssertEqual(session.audioTracks.count, 1)
        XCTAssertEqual(session.resumeTime, 900)
        XCTAssertEqual(MockURLProtocol.recorded(method: "POST", path: path).count, 1)
    }

    func testUpdateProgressPatchesComputedRatio() async throws {
        let path = Endpoints.progress("it1")
        MockURLProtocol.stub(method: "PATCH", path: path, json: "{}")
        try await client.updateProgress(itemId: "it1", currentTime: 900, duration: 3600, finished: false)

        let request = try XCTUnwrap(MockURLProtocol.recorded(method: "PATCH", path: path).first)
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:8099/api/me/progress/it1")
        let body = try XCTUnwrap(MockURLProtocol.body(of: request))
        let update = try JSONDecoder().decode(ProgressUpdate.self, from: body)
        XCTAssertEqual(update.currentTime, 900, accuracy: 0.001)
        XCTAssertEqual(update.duration, 3600, accuracy: 0.001)
        XCTAssertEqual(update.progress, 0.25, accuracy: 0.001)
        XCTAssertEqual(update.isFinished, false)
    }

    func testUpdateProgressWithZeroDurationDoesNotDivide() async throws {
        let path = Endpoints.progress("it1")
        MockURLProtocol.stub(method: "PATCH", path: path, json: "{}")
        try await client.updateProgress(itemId: "it1", currentTime: 10, duration: 0, finished: true)
        let body = try XCTUnwrap(MockURLProtocol.body(of: XCTUnwrap(MockURLProtocol.recorded(method: "PATCH", path: path).last)))
        let update = try JSONDecoder().decode(ProgressUpdate.self, from: body)
        XCTAssertEqual(update.progress, 0, accuracy: 0.0001)
        XCTAssertEqual(update.isFinished, true)
    }

    func testClosePlaybackSessionTargetsSessionEndpoint() async throws {
        let path = Endpoints.sessionClose("ses1")
        MockURLProtocol.stub(method: "POST", path: path, json: "{}")
        try await client.closePlaybackSession(sessionId: "ses1")
        XCTAssertEqual(MockURLProtocol.recorded(method: "POST", path: path).count, 1)
    }

    // MARK: - Hata eşleme

    func testStatusCodesMapToTypedErrors() async {
        let cases: [(Int, AudiobookshelfError)] = [
            (401, .unauthorized),
            (403, .unauthorized),
            (404, .notFound),
            (500, .serverError(status: 500)),
            (418, .serverError(status: 418)),
        ]
        for (status, expected) in cases {
            MockURLProtocol.reset()
            MockURLProtocol.stub(method: "GET", path: Endpoints.libraries, status: status, json: "{}")
            do {
                _ = try await client.libraries()
                XCTFail("\(status) için hata beklenirken başarılı döndü")
            } catch let error as AudiobookshelfError {
                XCTAssertEqual(error, expected, "statusCode \(status) yanlış eşlendi")
            } catch {
                XCTFail("beklenmeyen hata tipi: \(error)")
            }
        }
    }

    func testInvalidJSONMapsToDecodingError() async {
        MockURLProtocol.stub(method: "GET", path: Endpoints.libraries, json: Fixture.brokenJSON)
        do {
            _ = try await client.libraries()
            XCTFail("decoding hatası bekleniyordu")
        } catch let error as AudiobookshelfError {
            guard case .decoding = error else {
                return XCTFail("decoding yerine \(error) alındı")
            }
        } catch {
            XCTFail("beklenmeyen hata tipi: \(error)")
        }
    }

    func testTransportFailureMapsToTransportError() async {
        MockURLProtocol.failTransport(URLError(.timedOut))
        do {
            _ = try await client.libraries()
            XCTFail("transport hatası bekleniyordu")
        } catch let error as AudiobookshelfError {
            guard case .transport(let message) = error else {
                return XCTFail("transport yerine \(error) alındı")
            }
            XCTAssertTrue(message.contains("-1001"), "hata metni kaynağı taşımıyor: \(message)")
        } catch {
            XCTFail("beklenmeyen hata tipi: \(error)")
        }
    }

    // MARK: - Yol türetme

    func testAbsoluteURLKeepsAbsoluteAndJoinsRelative() {
        XCTAssertEqual(
            PlayerViewModel.absoluteURL("https://cdn.example/x.m3u8", baseURL: Fixture.baseURL)?.absoluteString,
            "https://cdn.example/x.m3u8"
        )
        XCTAssertEqual(
            PlayerViewModel.absoluteURL("/stream/hls/it1/master.m3u8", baseURL: Fixture.baseURL)?.absoluteString,
            "http://127.0.0.1:8099/stream/hls/it1/master.m3u8"
        )
    }

    func testCoverDataReturnsRawBytes() async throws {
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        let path = Endpoints.cover("it1")
        MockURLProtocol.stub(method: "GET", path: path, data: png)
        let data = try await client.coverData(itemId: "it1")
        XCTAssertEqual(data, png)
    }
}
