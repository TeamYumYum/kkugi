import XCTest
@testable import Kkugi

final class SessionVaultTests: XCTestCase {
    func testStoreRotateAndRemoveAcrossInstances() throws {
        let service = "com.kkugi.tests." + UUID().uuidString
        let vault = SessionVault(service: service)
        addTeardownBlock { try vault.clear() }
        XCTAssertNil(try vault.read())
        let sessionID = UUID()
        let initial = StoredSession(sessionID: sessionID, memberID: 42, onboarded: false, accessToken: "test-access", refreshToken: "test-refresh")
        let rotated = StoredSession(sessionID: sessionID, memberID: 42, onboarded: false, accessToken: "new-access", refreshToken: "new-refresh")
        try vault.save(initial)
        XCTAssertEqual(try SessionVault(service: service).read(), initial)
        try vault.save(rotated)
        XCTAssertEqual(try vault.read(), rotated)
        try vault.clear()
        try vault.clear()
        XCTAssertNil(try vault.read())
    }
}
