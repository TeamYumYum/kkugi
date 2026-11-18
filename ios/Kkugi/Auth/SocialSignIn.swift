import GoogleSignIn
import KakaoSDKAuth
import KakaoSDKCommon
import KakaoSDKUser
import UIKit

@MainActor
enum SocialSignIn {
    static func token(for provider: LoginProvider) async throws -> String {
        switch provider {
        case .google:
            guard let client = setting("GIDClientID"), let server = setting("GIDServerClientID"),
                  schemes.contains(client.split(separator: ".").reversed().joined(separator: ".")),
                  let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive }),
                  var presenter = scene.keyWindow?.rootViewController else { throw URLError(.badURL) }
            while let presented = presenter.presentedViewController { presenter = presented }
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: client, serverClientID: server)
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let token = result.user.idToken?.tokenString, !token.isEmpty else { throw URLError(.userAuthenticationRequired) }
            return token
        case .kakao:
            guard let key = setting("KkugiKakaoAppKey") else { throw URLError(.badURL) }
            KakaoSDK.initSDK(appKey: key)
            return try await withCheckedThrowingContinuation { continuation in
                let callback: (OAuthToken?, Error?) -> Void = { response, error in
                    if let error { continuation.resume(throwing: error) }
                    else if let token = response?.accessToken, !token.isEmpty { continuation.resume(returning: token) }
                    else { continuation.resume(throwing: URLError(.userAuthenticationRequired)) }
                }
                if UserApi.isKakaoTalkLoginAvailable() {
                    UserApi.shared.loginWithKakaoTalk(completion: callback)
                } else {
                    UserApi.shared.loginWithKakaoAccount(completion: callback)
                }
            }
        case .review: throw URLError(.unsupportedURL)
        }
    }

    static func handle(_ url: URL) {
        if setting("KkugiKakaoAppKey") != nil && AuthApi.isKakaoTalkLoginUrl(url) {
            _ = AuthController.handleOpenUrl(url: url)
        } else if setting("GIDClientID") != nil {
            _ = GIDSignIn.sharedInstance.handle(url)
        }
    }

    private static var schemes: [String] {
        let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        return types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
    }

    private static func setting(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty, !value.hasPrefix("$(") else { return nil }
        return value
    }
}
