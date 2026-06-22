import XCTest
@testable import LotteryKit

final class SmokeTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(LotteryKit.version, "1.0.0")
    }
}
