import Foundation

enum AudiobookshelfError: Error, Equatable {
    case invalidURL
    case missingToken
    case unauthorized
    case notFound
    case serverError(status: Int)
    case decoding(String)
    case transport(String)
}

actor AudiobookshelfClient {
    private let trustController = ServerTrustController()
    private let session: URLSession
    private var baseURL: URL
    private var token: String?

    init(baseURL: URL, token: String? = nil, sessionConfiguration: URLSessionConfiguration? = nil) {
        self.baseURL = baseURL
        self.token = token
        let configuration = sessionConfiguration ?? {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 20
            return config
        }()
        self.session = URLSession(configuration: configuration, delegate: trustController, delegateQueue: nil)
    }

    func configure(baseURL: URL, token: String?) {
        self.baseURL = baseURL
        self.token = token
    }

    // MARK: - Endpoints

    func login(username: String, password: String) async throws -> LoginResponse {
        let request = try makeRequest(
            path: Endpoints.login,
            method: "POST",
            body: LoginRequest(username: username, password: password),
            authenticated: false
        )
        let response = try await send(request, as: LoginResponse.self)
        token = response.user.token ?? token
        return response
    }

    func libraries() async throws -> [Library] {
        let request = try makeRequest(path: Endpoints.libraries)
        return try await send(request, as: LibrariesResponse.self).libraries
    }

    func items(in libraryId: String) async throws -> [LibraryItem] {
        let request = try makeRequest(path: Endpoints.libraryItems(libraryId))
        return try await send(request, as: LibraryItemsResponse.self).results
    }

    func item(id: String) async throws -> LibraryItem {
        let request = try makeRequest(path: Endpoints.item(id))
        return try await send(request, as: LibraryItem.self)
    }

    func startPlaybackSession(itemId: String) async throws -> PlaybackSession {
        let request = try makeRequest(path: Endpoints.play(itemId), method: "POST")
        return try await send(request, as: PlaybackSession.self)
    }

    func closePlaybackSession(sessionId: String) async throws {
        let request = try makeRequest(path: Endpoints.sessionClose(sessionId), method: "POST")
        try await sendStatusOnly(request)
    }

    func updateProgress(itemId: String, currentTime: Double, duration: Double, finished: Bool) async throws {
        let body = ProgressUpdate(
            currentTime: currentTime,
            duration: duration,
            progress: duration > 0 ? currentTime / duration : 0,
            isFinished: finished
        )
        let request = try makeRequest(path: Endpoints.progress(itemId), method: "PATCH", body: body)
        try await sendStatusOnly(request)
    }

    func coverData(itemId: String) async throws -> Data {
        let request = try makeRequest(path: Endpoints.cover(itemId))
        return try await data(for: request)
    }

    func me() async throws -> User {
        let request = try makeRequest(path: Endpoints.me)
        return try await send(request, as: User.self)
    }

    // MARK: - HTTP

    private func makeRequest(path: String, method: String = "GET", authenticated: Bool = true) throws -> URLRequest {
        var request = URLRequest(url: try url(for: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if authenticated {
            request.setValue("Bearer \(try requireToken())", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func makeRequest<B: Encodable>(path: String, method: String, body: B, authenticated: Bool = true) throws -> URLRequest {
        var request = try makeRequest(path: path, method: method, authenticated: authenticated)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func requireToken() throws -> String {
        guard let token, !token.isEmpty else { throw AudiobookshelfError.missingToken }
        return token
    }

    private func url(for path: String) throws -> URL {
        let base = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + path) else { throw AudiobookshelfError.invalidURL }
        return url
    }

    private func send<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let data = try await data(for: request)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AudiobookshelfError.decoding("\(error)")
        }
    }

    private func sendStatusOnly(_ request: URLRequest) async throws {
        _ = try await data(for: request)
    }

    private func data(for request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AudiobookshelfError.transport("\(error)")
        }
        guard let http = response as? HTTPURLResponse else {
            throw AudiobookshelfError.serverError(status: -1)
        }
        switch http.statusCode {
        case 200...299:
            return data
        case 401, 403:
            throw AudiobookshelfError.unauthorized
        case 404:
            throw AudiobookshelfError.notFound
        default:
            throw AudiobookshelfError.serverError(status: http.statusCode)
        }
    }
}
