import XCTest
@testable import LotteryKit

final class BetExpansionTests: XCTestCase {
    func testSSQCompoundBetExpandsToAllSingleBets() {
        let bet = Bet(front: [1, 2, 3, 4, 5, 6, 7], back: [16])

        let singles = bet.expandedSingles(category: .ssq)

        XCTAssertEqual(singles.count, 7)
        XCTAssertTrue(singles.contains(Bet(front: [1, 2, 3, 4, 5, 6], back: [16])))
        XCTAssertTrue(singles.contains(Bet(front: [2, 3, 4, 5, 6, 7], back: [16])))
    }

    func testDLTCompoundBetExpandsAcrossFrontAndBackCombinations() {
        let bet = Bet(front: [1, 2, 3, 4, 5, 6], back: [1, 2, 3])

        let singles = bet.expandedSingles(category: .dlt)

        XCTAssertEqual(singles.count, 18)
        XCTAssertTrue(singles.contains(Bet(front: [1, 2, 3, 4, 5], back: [1, 2])))
        XCTAssertTrue(singles.contains(Bet(front: [2, 3, 4, 5, 6], back: [2, 3])))
    }

    func testEvaluateTicketSumsExpandedCompoundBetWinnings() {
        let bet = Bet(front: [1, 2, 3, 4, 5, 6, 7], back: [16])

        let evaluation = PrizeEvaluator.evaluateTicket(category: .ssq,
                                                       bets: [bet],
                                                       drawFront: [1, 2, 3, 4, 5, 6],
                                                       drawBack: [16],
                                                       prizes: ["一等奖": 8_000_000])

        XCTAssertEqual(evaluation.results.count, 7)
        XCTAssertEqual(evaluation.totalAmount, 8_018_000)
        XCTAssertEqual(evaluation.results.filter { $0.result.tierName == "一等奖" }.count, 1)
        XCTAssertEqual(evaluation.results.filter { $0.result.tierName == "三等奖" }.count, 6)
    }

    func testCompoundBetValidationAllowsMoreThanSingleBetCounts() {
        XCTAssertNil(NumberValidation.validateBet(category: .ssq,
                                                  front: [1, 2, 3, 4, 5, 6, 7],
                                                  back: [16]))
        XCTAssertNil(NumberValidation.validateBet(category: .dlt,
                                                  front: [1, 2, 3, 4, 5, 6],
                                                  back: [1, 2, 3]))
    }
}
