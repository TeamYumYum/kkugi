import Foundation

actor AuthSession {
    private let api: AuthClient
    private let vault: SessionVault
    private var generation = UUID()
    private var expiryObservers: [UUID: AsyncStream<Void>.Continuation] = [:]
    private var refreshTask: Task<StoredSession, Error>?

    init(api: AuthClient, vault: SessionVault) {
        self.api = api
        self.vault = vault
    }

    func expirations() -> AsyncStream<Void> {
        let observer = UUID()
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        expiryObservers[observer] = continuation
        continuation.onTermination = { [weak self] _ in Task { await self?.removeObserver(observer) } }
        return stream
    }

    private func removeObserver(_ id: UUID) { expiryObservers[id] = nil }

    func current() throws -> StoredSession? { try vault.read() }

    func protectedRequest(_ path: String, method: String, body: Data? = nil, query: [URLQueryItem] = [], contentType: String = "application/json") async throws -> Data {
        guard let original = try vault.read() else { throw URLError(.userAuthenticationRequired) }
        var response = try await api.request(path, method: method, body: body, bearer: original.accessToken, query: query, contentType: contentType)
        if response.1 == 401 {
            let renewed = try await refreshed(after: original)
            response = try await api.request(path, method: method, body: body, bearer: renewed.accessToken, query: query, contentType: contentType)
        }
        guard try vault.read()?.sessionID == original.sessionID else { throw CancellationError() }
        guard (200..<300).contains(response.1) else { throw AuthClient.RequestFailure(status: response.1, code: nil) }
        return response.0
    }

    func readEvents(_ path: String, body: Data,
                    receive: @Sendable (String, String) async throws -> Bool) async throws {
        guard let original = try vault.read() else { throw URLError(.userAuthenticationRequired) }
        var (bytes, status) = try await api.stream(path, body: body, bearer: original.accessToken)
        if status == 401 {
            bytes.task.cancel()
            let renewed = try await refreshed(after: original)
            (bytes, status) = try await api.stream(path, body: body, bearer: renewed.accessToken)
        }
        defer { bytes.task.cancel() }
        guard (200..<300).contains(status) else { throw AuthClient.RequestFailure(status: status, code: nil) }
        var parser = ServerEventParser()
        for try await byte in bytes {
            if let frame = try parser.consume(byte) {
                try Task.checkCancellation()
                guard try vault.read()?.sessionID == original.sessionID else { throw CancellationError() }
                if try await receive(frame.name, frame.data) { return }
            }
        }
        throw URLError(.networkConnectionLost)
    }

    func markOnboarded(for id: UUID) throws {
        guard let item = try vault.read(), item.sessionID == id else { throw CancellationError() }
        try vault.save(StoredSession(sessionID: id, memberID: item.memberID, onboarded: true,
                                     accessToken: item.accessToken, refreshToken: item.refreshToken))
    }

    func review(loginID: String, password: String) async throws -> LoginResponse {
        let attempt = beginOperation()
        let result = try await api.review(loginID: loginID, password: password)
        return try accept(result, attempt: attempt)
    }

    func social(provider: SocialProvider, token: String) async throws -> LoginResponse {
        let attempt = beginOperation()
        let result = try await api.social(provider: provider, providerToken: token)
        return try accept(result, attempt: attempt)
    }

    private func accept(_ result: LoginResponse, attempt: UUID) throws -> LoginResponse {
        guard generation == attempt else { throw CancellationError() }
        try vault.save(StoredSession(sessionID: UUID(), memberID: result.memberId, onboarded: result.onboarded, accessToken: result.accessToken, refreshToken: result.refreshToken))
        return result
    }

    private func beginOperation() -> UUID {
        generation = UUID()
        refreshTask?.cancel()
        refreshTask = nil
        return generation
    }

    func refreshed(after rejected: StoredSession) async throws -> StoredSession {
        guard let previous = try vault.read() else { throw URLError(.userAuthenticationRequired) }
        guard previous.sessionID == rejected.sessionID else { throw CancellationError() }
        guard previous.accessToken == rejected.accessToken else { return previous }
        if let refreshTask { return try await refreshTask.value }
        let attempt = generation
        let task = Task<StoredSession, Error> {
            defer { if generation == attempt { refreshTask = nil } }
            do {
                let tokens = try await api.refresh(token: previous.refreshToken)
                guard generation == attempt else { throw CancellationError() }
                guard let current = try vault.read(), current.sessionID == previous.sessionID else { throw CancellationError() }
                let updated = StoredSession(sessionID: current.sessionID, memberID: current.memberID, onboarded: current.onboarded, accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
                try vault.save(updated)
                return updated
            } catch let error as AuthClient.RequestFailure {
                if generation == attempt && error.status == 401 {
                    try vault.clear()
                    for observer in expiryObservers.values { observer.yield(()) }
                }
                throw error
            }
        }
        refreshTask = task
        return try await task.value
    }

    func withdraw() async throws {
        guard let member = try vault.read() else { throw URLError(.userAuthenticationRequired) }
        let response = try await protectedRequest("api/v1/members/me", method: "DELETE")
        let envelope = try JSONDecoder().decode(ApiResponseVoid.self, from: response)
        guard envelope.success == true else { throw URLError(.badServerResponse) }
        guard try vault.read()?.sessionID == member.sessionID else { throw CancellationError() }
        _ = beginOperation()
        try vault.clear()
    }

    func logout() async throws {
        let attempt = beginOperation()
        guard let session = try vault.read() else { return }
        try await api.logout(accessToken: session.accessToken)
        guard generation == attempt else { throw CancellationError() }
        try vault.clear()
    }
}
