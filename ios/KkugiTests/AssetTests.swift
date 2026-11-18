import CoreText
import XCTest
@testable import Kkugi

final class AssetTests: XCTestCase {
    func testEveryLoginImageDecodesFromTheAppBundle() {
        for asset in BundledArt.Asset.allCases {
            let image = BundledArt.load(asset)
            XCTAssertNotNil(image, "Cannot decode \(asset.rawValue)")
            XCTAssertGreaterThan(image?.size.width ?? 0, 0)
            XCTAssertGreaterThan(image?.size.height ?? 0, 0)
        }
    }

    func testNotoFontIsRegisteredAndWeightAxisIsApplied() {
        let regular = GFont.uiFont(size: 18, weight: 400)
        let bold = GFont.uiFont(size: 18, weight: 700)
        XCTAssertTrue(regular.fontName.hasPrefix("NotoSansKR"), "Unexpected fallback: \(regular.fontName)")
        XCTAssertTrue(bold.fontName.hasPrefix("NotoSansKR"))
        let regularAxes = CTFontCopyVariation(regular as CTFont) as? [NSNumber: NSNumber]
        let boldAxes = CTFontCopyVariation(bold as CTFont) as? [NSNumber: NSNumber]
        XCTAssertEqual(regularAxes?[NSNumber(value: 0x77676874)]?.intValue, 400)
        XCTAssertEqual(boldAxes?[NSNumber(value: 0x77676874)]?.intValue, 700)
    }
}
