import Foundation
import XCTest

// URLSession'ı ağa çıkmadan sahte yanıtla besleyen URLProtocol.
// Testler sıralı çalışır (XCTest paralelizasyonu kapalı), bu yüzden global durum güvenlidir.
final class MockURLProtocol: URLProtocol {
    struct Reply {
        let status: Int
        let data: Data
    }

    private static let lock = NSLock()
    private static var stubs: [(matches: (URLRequest) -> Bool, reply: Reply)] = []
    private static var seen: [URLRequest] = []
    private static var transportError: Error?

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        stubs = []
        seen = []
        transportError = nil
    }

    static func stub(method: String, path: String, status: Int = 200, json: String) {
        stub(method: method, path: path, status: status, data: Data(json.utf8))
    }

    static func stub(method: String, path: String, status: Int = 200, data: Data = Data()) {
        lock.lock(); defer { lock.unlock() }
        stubs.append((
            matches: { req in
                req.httpMethod == method && req.url?.path == path
            },
            reply: Reply(status: status, data: data)
        ))
    }

    static func failTransport(_ error: Error) {
        lock.lock(); defer { lock.unlock() }
        transportError = error
    }

    static func recorded(method: String, path: String? = nil) -> [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return seen.filter { req in
            req.httpMethod == method && (path == nil || req.url?.path == path)
        }
    }

    static func configuration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        config.timeoutIntervalForRequest = 2
        return config
    }

    // Gövde bazen stream olarak gelir; ikisini de oku.
    static func body(of request: URLRequest) -> Data? {
        if let data = request.httpBody { return data }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        MockURLProtocol.lock.lock()
        let error = MockURLProtocol.transportError
        let reply = MockURLProtocol.stubs.first { $0.matches(request) }?.reply
        MockURLProtocol.seen.append(request)
        MockURLProtocol.lock.unlock()

        if let error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        guard let reply else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "http://127.0.0.1:8099")!,
            statusCode: reply.status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

enum Fixture {
    static let baseURL = URL(string: "http://127.0.0.1:8099")!

    static let login = """
    {"user":{"id":"u1","username":"tuna","token":"tok-123","mediaProgress":[]},
     "userDefaultLibraryId":"lib1"}
    """

    static let me = """
    {"id":"u1","username":"tuna","token":"tok-123","mediaProgress":[]}
    """

    static let libraries = """
    {"libraries":[{"id":"lib1","name":"Kitaplar","mediaType":"book"}]}
    """

    static let items = """
    {"results":[
      {"id":"it1","libraryId":"lib1","mediaType":"book",
       "media":{"metadata":{"title":"Dune","authorName":"Frank Herbert"},"tracks":[]}},
      {"id":"it2","libraryId":"lib1","mediaType":"book","media":null}
    ]}
    """

    static let playSession = """
    {"id":"ses1","itemId":"it1","duration":3600,"progress":0.25,"currentTime":900,
     "mediaProgress":{"currentTime":900,"progress":0.25,"isFinished":false},
     "audioTracks":[{"index":0,"title":"01","contentUrl":"/stream/hls/it1/master.m3u8","duration":3600,"mimeType":"audio/mpegurl"}]}
    """

    static let brokenJSON = "{ this is not json"

    static var firstItem: LibraryItem {
        LibraryItem(id: "it1", libraryId: "lib1", mediaType: "book",
                    media: LibraryItem.Media(
                        metadata: LibraryItem.Media.Metadata(title: "Dune", authorName: "Frank Herbert"),
                        tracks: nil))
    }

    static var untitledItem: LibraryItem {
        LibraryItem(id: "it2", libraryId: nil, mediaType: nil, media: nil)
    }
}

extension XCTestCase {
    /// Fire-and-forget Task'lerin (stop/flush) bitmesini bekler.
    func waitUntil(timeout: TimeInterval = 2, _ condition: @escaping () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}
