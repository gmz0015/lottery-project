import XCTest
@testable import LotteryKit

final class SmokeTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(LotteryKitInfo.version, "1.0.0")
    }
}
