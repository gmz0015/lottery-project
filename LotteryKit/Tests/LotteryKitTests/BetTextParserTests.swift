import XCTest
@testable import LotteryKit

final class BetTextParserTests: XCTestCase {
    func testParsesMultipleBetLines() throws {
        let bets = try BetTextParser.parse(category: .ssq,
                                           frontText: "1 2 3 4 5 6\n7,8,9,10,11,12",
                                           backText: "16\n01")

        XCTAssertEqual(bets, [
            Bet(front: [1, 2, 3, 4, 5, 6], back: [16]),
            Bet(front: [7, 8, 9, 10, 11, 12], back: [1]),
        ])
    }

    func testParsesSingleCompoundBetLine() throws {
        let bets = try BetTextParser.parse(category: .dlt,
                                           frontText: "1 2 3 4 5 6",
                                           backText: "1 2 3")

        XCTAssertEqual(bets, [Bet(front: [1, 2, 3, 4, 5, 6], back: [1, 2, 3])])
    }

    func testRejectsMismatchedLineCounts() {
        XCTAssertThrowsError(try BetTextParser.parse(category: .ssq,
                                                     frontText: "1 2 3 4 5 6\n7 8 9 10 11 12",
                                                     backText: "16")) { error in
            XCTAssertEqual(error as? BetTextParser.Error, .lineCountMismatch(front: 2, back: 1))
        }
    }

    func testReportsInvalidLine() {
        XCTAssertThrowsError(try BetTextParser.parse(category: .ssq,
                                                     frontText: "1 2 3",
                                                     backText: "16")) { error in
            XCTAssertEqual(error as? BetTextParser.Error,
                           .invalidBet(line: 1, message: "前区/红球至少需要 6 个号码"))
        }
    }
}
