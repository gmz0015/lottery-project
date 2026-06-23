import XCTest
@testable import LotteryKit

final class PrizeEvaluatorDLTTests: XCTestCase {
    let df = [1,2,3,4,5]; let db = [1,2]

    func eval(_ f: [Int], _ b: [Int], prizes: [String:Int]? = nil) -> BetResult {
        PrizeEvaluator.evaluate(category: .dlt, bet: Bet(front: f, back: b), drawFront: df, drawBack: db, prizes: prizes)
    }

    func testFirstFloating() {
        XCTAssertEqual(eval([1,2,3,4,5], [1,2], prizes: ["一等奖": 10000000]).amount, 10000000)
    }
    func testSecondNoData() { XCTAssertNil(eval([1,2,3,4,5], [1,11]).amount) }
    func testThird()  { XCTAssertEqual(eval([1,2,3,4,5], [10,11]).amount, 10000) }
    func testFourth() { XCTAssertEqual(eval([1,2,3,4,30], [1,2]).amount, 3000) }
    func testFifth()  { XCTAssertEqual(eval([1,2,3,4,30], [1,11]).amount, 300) }
    func testSixth()  { XCTAssertEqual(eval([1,2,3,30,31], [1,2]).amount, 200) }
    func testSeventh(){ XCTAssertEqual(eval([1,2,3,4,30], [10,11]).amount, 100) }
    func testEighthByThreeOne() { XCTAssertEqual(eval([1,2,3,30,31], [1,11]).tierName, "八等奖") }
    func testEighthByTwoTwo()   { XCTAssertEqual(eval([1,2,30,31,32], [1,2]).tierName, "八等奖") }
    func testNinth()  { XCTAssertEqual(eval([1,2,30,31,32], [1,11]).amount, 5) }
    func testNoWin()  { XCTAssertFalse(eval([30,31,32,33,34], [10,11]).isWin) }
}
