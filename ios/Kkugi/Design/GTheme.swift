import CoreText
import SwiftUI
import UIKit

/// Mirrors Android GTheme.G_DESIGN_SCALE, including scaled type and dimensions.
enum G {
    static let scale: CGFloat = 1.2
    static func dp(_ value: CGFloat) -> CGFloat { value * scale }
    static let small = dp(8)
    static let gap = dp(12)
    static let gutter = dp(18)
    static let buttonHeight = dp(52)
    static let lineHeight: CGFloat = 1.45
    static let letterSpacing: CGFloat = -0.01
}

enum GColor {
    static let text = Color(hex: 0x1F2328)
    static let muted = Color(hex: 0x868E96)
    static let surface = Color.white
    static let outline = Color(hex: 0xDDE2E8)
    static let disabled = Color(hex: 0xD5DAE0)
    static let kakao = Color(hex: 0xFEE500)
    static let kakaoInk = Color(hex: 0x191600)
    static let loginSky = Color(hex: 0xF5E8D9)
    static let loginPanel = Color(hex: 0xFAF5EC)
    static let loginInk = Color(hex: 0x3B3A2A)
    static let loginInkSoft = Color(hex: 0x6B6650)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: 1
        )
    }
}

extension View {
    func gListCanvas() -> some View {
        let canvas = Color(hex: 0xF5F7FA)
        return scrollContentBackground(.hidden)
            .background(canvas)
            .toolbarBackground(canvas, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
    }
}

enum GFont {
    static let postScriptName = "NotoSansKR-Thin"

    static func uiFont(size: CGFloat, weight: Int) -> UIFont {
        // The original font is a variable font. Select its wght axis, not synthetic bold.
        let variation = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
        let descriptor = UIFontDescriptor(name: postScriptName, size: size)
            .addingAttributes([variation: [NSNumber(value: 0x77676874): NSNumber(value: weight)]])
        return UIFont(descriptor: descriptor, size: size)
    }
}

struct GText: View {
    let text: String
    var size: CGFloat = 13
    var weight: Int = 400
    var color: Color = GColor.text
    var alignment: TextAlignment = .leading
    var underline = false
    var trackingAdjustment: CGFloat = 0
    @ScaledMetric(relativeTo: .body) private var fontScale: CGFloat = 1

    var body: some View {
        let pointSize = G.dp(size) * fontScale
        let font = GFont.uiFont(size: pointSize, weight: weight)
        let extraLeading = max(0, pointSize * G.lineHeight - font.lineHeight)
        Text(text)
            .font(Font(font))
            .tracking(pointSize * G.letterSpacing + trackingAdjustment * fontScale)
            .lineSpacing(extraLeading)
            .padding(.vertical, extraLeading / 2)
            .foregroundStyle(color)
            .multilineTextAlignment(alignment)
            .underline(underline)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct GButtonStyle: ButtonStyle {
    let background: Color
    let outline: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: G.buttonHeight)
            .background(background, in: Capsule())
            .overlay {
                if outline {
                    Capsule().strokeBorder(GColor.outline, lineWidth: G.dp(1.5))
                }
            }
            .overlay {
                if configuration.isPressed {
                    Capsule().fill(GColor.text.opacity(0.08))
                }
            }
            .contentShape(Capsule())
    }
}
