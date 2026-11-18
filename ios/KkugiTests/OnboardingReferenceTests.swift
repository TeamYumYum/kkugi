import SwiftUI
import XCTest
@testable import Kkugi

final class OnboardingReferenceTests: XCTestCase {
    @MainActor func testFixedSizeNativeOnboardingScreens() async throws {
        for (name, goal) in [("nickname", false), ("goal", true)] {
            let root = OnboardingScreen.reference(showGoal: goal)
                .environment(\.locale, Locale(identifier: "ko_KR"))
                .environment(\.displayScale, 3)
                .dynamicTypeSize(.large)
                .frame(width: 360, height: 720)
                .background(.white)
            let host = UIHostingController(rootView: root)
            host.safeAreaRegions = []
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: scene)
            window.rootViewController = host
            window.frame = CGRect(x: 0, y: 0, width: 360, height: 720)
            window.overrideUserInterfaceStyle = .light
            window.isHidden = false
            defer { window.isHidden = true }
            host.view.frame = window.bounds
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            await Task.yield()
            let format = UIGraphicsImageRendererFormat()
            format.scale = 3
            format.opaque = true
            format.preferredRange = .standard
            let size = CGSize(width: 360, height: 720)
            let bitmap = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                XCTAssertTrue(host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true))
            }
            XCTAssertEqual(bitmap.cgImage?.width, 1080)
            XCTAssertEqual(bitmap.cgImage?.height, 2160)
            let attachment = XCTAttachment(data: try XCTUnwrap(bitmap.pngData()), uniformTypeIdentifier: "public.png")
            attachment.name = "onboarding-\(name)-3x.png"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
