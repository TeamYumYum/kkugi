import XCTest
@testable import Kkugi

final class SessionVaultTests: XCTestCase {
    func testStoreRotateAndRemoveAcrossInstances() throws {
        let service = "com.kkugi.tests." + UUID().uuidString
        let vault = SessionVault(service: service)
        addTeardownBlock { try vault.clear() }
        XCTAssertNil(try vault.read())
        let initial = StoredSession(accessToken: "test-access", refreshToken: "test-refresh")
        let rotated = StoredSession(accessToken: "new-access", refreshToken: "new-refresh")
        try vault.save(initial)
        XCTAssertEqual(try SessionVault(service: service).read(), initial)
        try vault.save(rotated)
        XCTAssertEqual(try vault.read(), rotated)
        try vault.clear()
        try vault.clear()
        XCTAssertNil(try vault.read())
    }
}
