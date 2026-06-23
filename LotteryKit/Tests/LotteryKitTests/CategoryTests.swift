import XCTest
@testable import LotteryKit

final class CategoryTests: XCTestCase {
    func testCategoryRules() {
        XCTAssertEqual(Category.ssq.frontCount, 6)
        XCTAssertEqual(Category.ssq.frontMax, 33)
        XCTAssertEqual(Category.ssq.backCount, 1)
        XCTAssertEqual(Category.ssq.backMax, 16)
        XCTAssertEqual(Category.dlt.frontCount, 5)
        XCTAssertEqual(Category.dlt.backMax, 12)
    }

    func testSourceCategoryBinding() {
        XCTAssertEqual(DataSourceKind.officialSporttery.category, .dlt)
        XCTAssertEqual(DataSourceKind.officialCWL.category, .ssq)
        XCTAssertNil(DataSourceKind.webService.category)
    }
}
