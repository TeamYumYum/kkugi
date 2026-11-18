import SwiftUI
import XCTest
@testable import Kkugi

/// Captures actual SwiftUI pixels. These tests do not assert Android parity by themselves.
final class LoginSnapshotTests: XCTestCase {
    @MainActor
    func testLoginStatesAtFixedContentSize() throws {
        let cases: [(String, LoginState)] = [
            ("login-initial", LoginState()),
            ("login-recent-kakao", LoginState(recentProvider: .kakao)),
            ("login-kakao-busy", LoginState(signingIn: .kakao)),
            ("login-google-busy", LoginState(signingIn: .google)),
            ("login-error", LoginState(error: "로그인하지 못했어요. 다시 시도해 주세요"))
        ]
        for (name, state) in cases {
            for scale: CGFloat in [1, 3] {
                let view = LoginScreen(
                    state: state,
                    onSocialLogin: { _ in },
                    onReviewLogin: { _, _ in },
                    onDismissError: {}
                )
                .environment(\.locale, Locale(identifier: "ko_KR"))
                .environment(\.colorScheme, .light)
                .environment(\.displayScale, scale)
                .dynamicTypeSize(.large)
                .frame(width: 360, height: 720)
                let renderer = ImageRenderer(content: view)
                renderer.scale = scale
                renderer.isOpaque = true
                let cgImage = try XCTUnwrap(renderer.cgImage, "Missing render for \(name)")
                XCTAssertEqual(cgImage.width, Int(360 * scale))
                XCTAssertEqual(cgImage.height, Int(720 * scale))
                let image = UIImage(cgImage: cgImage)
                let png = try XCTUnwrap(image.pngData())
                let caseName = "\(name)-\(Int(scale))x"
                let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
                attachment.name = caseName + ".png"
                attachment.lifetime = .keepAlways
                add(attachment)
                let metadata: [String: Any] = [
                    "case": name,
                    "platform": "ios",
                    "renderer": "SwiftUI.ImageRenderer",
                    "widthPoints": 360,
                    "heightPoints": 720,
                    "scale": scale,
                    "widthPixels": cgImage.width,
                    "heightPixels": cgImage.height,
                    "locale": "ko_KR",
                    "dynamicTypeSize": "large",
                    "colorScheme": "light",
                    "safeArea": "excluded-content-only",
                    "os": ProcessInfo.processInfo.operatingSystemVersionString,
                    "sourceCommit": ProcessInfo.processInfo.environment["KKUGI_SOURCE_COMMIT"] ?? "unrecorded",
                    "androidParity": "not-yet-compared"
                ]
                let json = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                let details = XCTAttachment(data: json, uniformTypeIdentifier: "public.json")
                details.name = caseName + ".json"
                details.lifetime = .keepAlways
                add(details)
            }
        }
    }
}
