import XCTest
@testable import Kkugi

final class ServerEventParserTests: XCTestCase {
    func testKoreanTextAndSeparateFramesAcrossNewlineStyles() throws {
        var parser = ServerEventParser()
        let input = ": heartbeat\r\n\r\nevent: answer\r\ndata: 첫 줄\r\ndata: 둘째 줄\r\n\r\nevent: done\ndata: {}\n\n"
        let frames = try input.utf8.compactMap { try parser.consume($0) }
        XCTAssertEqual(frames.map(\.name), ["answer", "done"])
        XCTAssertEqual(frames.map(\.data), ["첫 줄\n둘째 줄", "{}"])
    }

    func testIncompleteFrameIsNotDelivered() throws {
        var parser = ServerEventParser()
        XCTAssertTrue(try "event: answer\ndata: 일부".utf8.compactMap { try parser.consume($0) }.isEmpty)
    }
}
