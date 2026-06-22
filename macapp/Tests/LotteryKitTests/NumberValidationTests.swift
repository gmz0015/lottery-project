import XCTest
@testable import LotteryKit

final class NumberValidationTests: XCTestCase {
    func testValid() {
        XCTAssertNil(NumberValidation.validate(category: .ssq, front: [1,2,3,4,5,6], back: [16]))
        XCTAssertNil(NumberValidation.validate(category: .dlt, front: [1,2,3,4,35], back: [1,12]))
    }
    func testWrongCount() {
        XCTAssertNotNil(NumberValidation.validate(category: .ssq, front: [1,2,3], back: [16]))
    }
    func testOutOfRange() {
        XCTAssertTrue(NumberValidation.validate(category: .ssq, front: [1,2,3,4,5,34], back: [16])!.contains("33"))
    }
    func testDuplicate() {
        XCTAssertTrue(NumberValidation.validate(category: .ssq, front: [1,2,3,4,5,5], back: [16])!.contains("重复"))
    }
}
