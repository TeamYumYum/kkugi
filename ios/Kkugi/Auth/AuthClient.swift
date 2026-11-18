import Foundation

enum SocialProvider: String { case kakao, google }

struct AuthClient {
    struct RequestFailure: Error {
        let status: Int
        let code: String?
    }

    let baseURL: URL
    let session: URLSession

    func review(loginID: String, password: String) async throws -> LoginResponse {
        try await login(path: "review", body: ReviewLoginRequest(loginId: loginID, password: password))
    }

    func social(provider: SocialProvider, providerToken: String) async throws -> LoginResponse {
        try await login(path: provider.rawValue, body: SocialLoginRequest(providerToken: providerToken))
    }

    private func login<Body: Encodable>(path: String, body: Body) async throws -> LoginResponse {
        let (data, status) = try await post("login/" + path, body: JSONEncoder().encode(body))
        let response = try JSONDecoder().decode(ApiResponseLoginResponse.self, from: data)
        guard (200..<300).contains(status), response.success == true, let login = response.data,
              !login.accessToken.isEmpty, !login.refreshToken.isEmpty else {
            throw RequestFailure(status: status, code: response.error?.code)
        }
        return login
    }

    func refresh(token: String) async throws -> TokenResponse {
        let body = try JSONEncoder().encode(RefreshTokenRequest(refreshToken: token))
        let (data, status) = try await post("refresh", body: body)
        let response = try JSONDecoder().decode(ApiResponseTokenResponse.self, from: data)
        guard (200..<300).contains(status), response.success == true, let tokens = response.data,
              !tokens.accessToken.isEmpty, !tokens.refreshToken.isEmpty else {
            throw RequestFailure(status: status, code: response.error?.code)
        }
        return tokens
    }

    func logout(accessToken: String) async throws {
        let (_, status) = try await post("logout", bearer: accessToken)
        guard (200..<300).contains(status) else { throw RequestFailure(status: status, code: nil) }
    }

    private func post(_ path: String, body: Data? = nil, bearer: String? = nil) async throws -> (Data, Int) {
        try await request("api/v1/auth/" + path, method: "POST", body: body, bearer: bearer)
    }

    func request(_ path: String, method: String, body: Data?, bearer: String?) async throws -> (Data, Int) {
        guard baseURL.scheme == "https", baseURL.host != nil else { throw URLError(.badURL) }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.httpBody = body
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let bearer { request.setValue("Bearer " + bearer, forHTTPHeaderField: "Authorization") }
        let (data, response) = try await session.data(for: request, delegate: AuthRedirectPolicy())
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http.statusCode)
    }
}

private final class AuthRedirectPolicy: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
