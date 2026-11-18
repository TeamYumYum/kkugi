import ImageIO
import SwiftUI
import UIKit

enum BundledArt {
    enum Asset: String, CaseIterable {
        case idle = "kkugi_g_character_f_idle"
        case heart = "kkugi_g_character_heart"
        case homeBack = "kkugi_garden_back"
        case homeFront = "kkugi_garden_front"
        case homeWalk = "kkugi_garden_walk_loop_still"
        case gardenBack = "member_login_garden_back"
        case gardenFront = "member_login_garden_front"
        case wave = "kkugi_g_character_wave"
        case google = "member_google_g_logo"

        var fileExtension: String { self == .google ? "png" : "webp" }
    }

    static func load(_ asset: Asset) -> UIImage? {
        guard let url = Bundle.main.url(forResource: asset.rawValue, withExtension: asset.fileExtension, subdirectory: "Images"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        return UIImage(cgImage: image)
    }
}

struct ArtImage: View {
    let asset: BundledArt.Asset

    var body: some View {
        if let image = BundledArt.load(asset) {
            Image(uiImage: image).interpolation(.low).resizable()
        } else {
            // AssetTests fails for this case. Never replace the image with invented artwork.
            Color.clear
        }
    }
}

/// Exact cubic path and translation from Android member_kakao_symbol.xml.
struct KakaoSymbol: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 68.001, y: 16.5225))
        p.addCurve(to: CGPoint(x: 61.5225, y: 22.0641), control1: CGPoint(x: 64.4222, y: 16.5225), control2: CGPoint(x: 61.5225, y: 19.0037))
        p.addCurve(to: CGPoint(x: 64.5292, y: 26.7423), control1: CGPoint(x: 61.5225, y: 24.0312), control2: CGPoint(x: 62.7219, y: 25.7596))
        p.addLine(to: CGPoint(x: 63.9181, y: 29.2113))
        p.addCurve(to: CGPoint(x: 63.9619, y: 29.4184), control1: CGPoint(x: 63.8954, y: 29.285), control2: CGPoint(x: 63.9132, y: 29.364))
        p.addCurve(to: CGPoint(x: 64.0931, y: 29.478), control1: CGPoint(x: 63.9975, y: 29.457), control2: CGPoint(x: 64.0461, y: 29.478))
        p.addCurve(to: CGPoint(x: 64.2082, y: 29.4341), control1: CGPoint(x: 64.1337, y: 29.478), control2: CGPoint(x: 64.1742, y: 29.464))
        p.addLine(to: CGPoint(x: 66.834, y: 27.5144))
        p.addCurve(to: CGPoint(x: 67.9994, y: 27.6039), control1: CGPoint(x: 67.2117, y: 27.5723), control2: CGPoint(x: 67.6007, y: 27.6039))
        p.addCurve(to: CGPoint(x: 74.478, y: 22.0623), control1: CGPoint(x: 71.5767, y: 27.6039), control2: CGPoint(x: 74.478, y: 25.1226))
        p.addCurve(to: CGPoint(x: 68.001, y: 16.5225), control1: CGPoint(x: 74.478, y: 19.002), control2: CGPoint(x: 71.5783, y: 16.5225))
        p.closeSubpath()
        return p.applying(CGAffineTransform(translationX: -61.5225, y: -16.5225))
            .applying(CGAffineTransform(scaleX: rect.width / 13, y: rect.height / 13))
            .applying(CGAffineTransform(translationX: rect.minX, y: rect.minY))
    }
}
