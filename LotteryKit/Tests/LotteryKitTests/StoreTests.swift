import XCTest
@testable import LotteryKit

@MainActor
final class StoreTests: XCTestCase {
    func makeStore() throws -> Store { try Store(inMemory: true) }

    func testCreateOrGetDrawIsUniquePerTriple() throws {
        let s = try makeStore()
        let a = s.createOrGetDraw(category: .ssq, issue: "24001", source: .officialCWL)
        let b = s.createOrGetDraw(category: .ssq, issue: "24001", source: .officialCWL)
        XCTAssertEqual(a.id, b.id)
        let c = s.createOrGetDraw(category: .ssq, issue: "24001", source: .webService)
        XCTAssertNotEqual(a.id, c.id)
    }

    func testVersionNumberAutoIncrementsAndImmutable() throws {
        let s = try makeStore()
        let d = s.createOrGetDraw(category: .ssq, issue: "24001", source: .officialCWL)
        let v1 = s.addVersion(to: d, front: [1,2,3,4,5,6], back: [16], prizes: nil, drawDate: nil, origin: "fetched", sourceURL: "https://x")
        let v2 = s.addVersion(to: d, front: [1,2,3,4,5,7], back: [10], prizes: nil, drawDate: nil, origin: "manual", sourceURL: nil)
        XCTAssertEqual(v1.versionNumber, 1)
        XCTAssertEqual(v2.versionNumber, 2)
        XCTAssertEqual(s.latestVersion(d)?.id, v2.id)
        XCTAssertEqual(v1.backNumbers, [16])  // 旧版本不变
    }

    func testTicketAndVerificationRelation() throws {
        let s = try makeStore()
        let t = s.saveTicket(category: .ssq, issue: "24001",
                             bets: [Bet(front: [1,2,3,4,5,6], back: [16])],
                             imageFileName: "a.jpg", cost: 2, purchaseDate: Date())
        let d = s.createOrGetDraw(category: .ssq, issue: "24001", source: .officialCWL)
        let v = s.addVersion(to: d, front: [1,2,3,4,5,6], back: [16], prizes: nil, drawDate: nil, origin: "fetched", sourceURL: nil)
        let snap = BetResultSnapshot(bet: Bet(front: [1,2,3,4,5,6], back: [16]),
                                     result: BetResult(tierName: "一等奖", amount: nil, frontMatched: [1,2,3,4,5,6], backMatched: [16]))
        let rec = s.addVerification(ticket: t, drawVersion: v, results: [snap], totalAmount: 0)
        XCTAssertEqual(t.verifications.count, 1)
        XCTAssertEqual(rec.drawVersion?.id, v.id)
        XCTAssertEqual(s.allTickets().count, 1)
    }
}
