import Foundation

actor AuthSession {
    private let api: AuthClient
    private let vault: SessionVault
    private var generation = UUID()
    private var refreshTask: Task<StoredSession, Error>?

    init(api: AuthClient, vault: SessionVault) {
        self.api = api
        self.vault = vault
    }

    func current() throws -> StoredSession? { try vault.read() }

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
                let updated = StoredSession(sessionID: previous.sessionID, memberID: previous.memberID, onboarded: previous.onboarded, accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
                try vault.save(updated)
                return updated
            } catch let error as AuthClient.RequestFailure {
                if generation == attempt && error.status == 401 { try vault.clear() }
                throw error
            }
        }
        refreshTask = task
        return try await task.value
    }

    func logout() async throws {
        let attempt = beginOperation()
        guard let session = try vault.read() else { return }
        try await api.logout(accessToken: session.accessToken)
        guard generation == attempt else { throw CancellationError() }
        try vault.clear()
    }
}
