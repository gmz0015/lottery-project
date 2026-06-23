import XCTest
@testable import LotteryKit

final class PrizeEvaluatorSSQTests: XCTestCase {
    let df = [1,2,3,4,5,6]; let db = [16]

    func eval(_ f: [Int], _ b: [Int], prizes: [String:Int]? = nil) -> BetResult {
        PrizeEvaluator.evaluate(category: .ssq, bet: Bet(front: f, back: b), drawFront: df, drawBack: db, prizes: prizes)
    }

    func testFirstPrizeFloating() {
        let r = eval([1,2,3,4,5,6], [16], prizes: ["一等奖": 8000000])
        XCTAssertEqual(r.tierName, "一等奖")
        XCTAssertEqual(r.amount, 8000000)
        XCTAssertTrue(r.isWin)
    }
    func testSecondPrizeNoPrizeData() {
        let r = eval([1,2,3,4,5,6], [9])
        XCTAssertEqual(r.tierName, "二等奖")
        XCTAssertNil(r.amount)
    }
    func testThird() { XCTAssertEqual(eval([1,2,3,4,5,30], [16]).tierName, "三等奖") }
    func testFourthByFiveZero() { XCTAssertEqual(eval([1,2,3,4,5,30], [9]).amount, 200) }
    func testFourthByFourOne() { XCTAssertEqual(eval([1,2,3,4,30,31], [16]).amount, 200) }
    func testFifth() { XCTAssertEqual(eval([1,2,3,4,30,31], [9]).amount, 10) }
    func testSixthBlueOnly() {
        let r = eval([30,31,32,33,28,29], [16])
        XCTAssertEqual(r.tierName, "六等奖")
        XCTAssertEqual(r.amount, 5)
    }
    func testNoWin() {
        let r = eval([30,31,32,33,28,29], [9])
        XCTAssertFalse(r.isWin)
        XCTAssertNil(r.tierName)
    }
    func testMatchedReported() {
        let r = eval([1,2,3,4,5,30], [16])
        XCTAssertEqual(Set(r.frontMatched), Set([1,2,3,4,5]))
        XCTAssertEqual(r.backMatched, [16])
    }
}
