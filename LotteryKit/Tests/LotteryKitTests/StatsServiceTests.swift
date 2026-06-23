import XCTest
@testable import LotteryKit

@MainActor
final class StatsServiceTests: XCTestCase {
    func makeTicket(_ store: Store, win: Int?, cost: Double, day: Date, cat: LotteryKit.Category = .ssq) -> Ticket {
        let t = store.saveTicket(category: cat, issue: "x", bets: [Bet(front: [1,2,3,4,5,6], back: [16])],
                                 imageFileName: nil, cost: cost, purchaseDate: day)
        if let win {
            let d = store.createOrGetDraw(category: cat, issue: "x", source: .manual)
            let v = store.addVersion(to: d, front: [1,2,3,4,5,6], back: [16], prizes: nil, drawDate: nil, origin: "manual", sourceURL: nil)
            let tier = win > 0 ? "三等奖" : nil
            let snap = BetResultSnapshot(bet: t.bets[0], result: BetResult(tierName: tier, amount: win, frontMatched: [], backMatched: []))
            _ = store.addVerification(ticket: t, drawVersion: v, results: [snap], totalAmount: win)
        }
        return t
    }

    func testSummary() throws {
        let store = try Store(inMemory: true)
        _ = makeTicket(store, win: 3000, cost: 2, day: Date())
        _ = makeTicket(store, win: 0, cost: 2, day: Date())
        _ = makeTicket(store, win: nil, cost: 2, day: Date())
        let stats = StatsService.latestVerifications(store.allTickets())
        let sum = StatsService.summary(stats)
        XCTAssertEqual(sum.ticketCount, 3)
        XCTAssertEqual(sum.totalCost, 6)
        XCTAssertEqual(sum.totalWin, 3000)
        XCTAssertEqual(sum.net, 2994)
        XCTAssertEqual(sum.winRate, 1.0/3.0, accuracy: 0.001)
    }

    func testFrequency() throws {
        let store = try Store(inMemory: true)
        _ = makeTicket(store, win: nil, cost: 2, day: Date())
        let freq = StatsService.myNumberFrequency(store.allTickets(), category: .ssq)
        XCTAssertEqual(freq[1], 1)
    }
}
