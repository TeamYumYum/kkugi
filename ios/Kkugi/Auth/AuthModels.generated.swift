// Generated from contracts/openapi.json by ios/scripts/auth_contract.py.

struct ReviewLoginRequest: Codable {
    let loginId: String
    let password: String
}

struct SocialLoginRequest: Codable {
    let providerToken: String
}

struct RefreshTokenRequest: Codable {
    let refreshToken: String
}

struct LoginResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let onboarded: Bool
    let memberId: Int64
    let role: String?
}

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let role: String?
}

struct ErrorDetail: Codable {
    let code: String?
    let message: String?
}

struct ApiResponseLoginResponse: Codable {
    let success: Bool?
    let data: LoginResponse?
    let error: ErrorDetail?
}

struct ApiResponseTokenResponse: Codable {
    let success: Bool?
    let data: TokenResponse?
    let error: ErrorDetail?
}

struct ApiResponseVoid: Codable {
    let success: Bool?
    let error: ErrorDetail?
}
