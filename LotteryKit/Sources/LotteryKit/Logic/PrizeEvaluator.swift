public struct BetResult: Equatable, Codable, Sendable {
    public let tierName: String?
    public let amount: Int?
    public let isWin: Bool
    public let frontMatched: [Int]
    public let backMatched: [Int]
    public init(tierName: String?, amount: Int?, frontMatched: [Int], backMatched: [Int]) {
        self.tierName = tierName
        self.amount = amount
        self.isWin = tierName != nil
        self.frontMatched = frontMatched
        self.backMatched = backMatched
    }
}

public struct TicketEvaluation: Equatable, Codable, Sendable {
    public let results: [BetResultSnapshot]
    public let totalAmount: Int
    public let isWin: Bool

    public init(results: [BetResultSnapshot], totalAmount: Int) {
        self.results = results
        self.totalAmount = totalAmount
        self.isWin = results.contains { $0.result.isWin }
    }
}

public enum PrizeEvaluator {
    public static func evaluate(category: Category, bet: Bet,
                                drawFront: [Int], drawBack: [Int],
                                prizes: [String: Int]?) -> BetResult {
        let fm = bet.front.filter { drawFront.contains($0) }
        let bm = bet.back.filter { drawBack.contains($0) }
        let r = fm.count, b = bm.count
        let (tier, fixed): (String?, Int?) = category == .ssq
            ? ssqTier(r: r, b: b) : dltTier(f: r, k: b)
        let amount: Int?
        if let tier, fixed == nil {        // 浮动奖
            amount = prizes?[tier]
        } else {
            amount = fixed
        }
        return BetResult(tierName: tier, amount: amount, frontMatched: fm, backMatched: bm)
    }

    public static func evaluateTicket(category: Category, bets: [Bet],
                                      drawFront: [Int], drawBack: [Int],
                                      prizes: [String: Int]?) -> TicketEvaluation {
        var total = 0
        var snapshots: [BetResultSnapshot] = []
        for bet in bets {
            for single in bet.expandedSingles(category: category) {
                let result = evaluate(category: category,
                                      bet: single,
                                      drawFront: drawFront,
                                      drawBack: drawBack,
                                      prizes: prizes)
                total += result.amount ?? 0
                snapshots.append(BetResultSnapshot(bet: single, result: result))
            }
        }
        return TicketEvaluation(results: snapshots, totalAmount: total)
    }

    static func ssqTier(r: Int, b: Int) -> (String?, Int?) {
        switch (r, b) {
        case (6, 1): return ("一等奖", nil)
        case (6, 0): return ("二等奖", nil)
        case (5, 1): return ("三等奖", 3000)
        case (5, 0), (4, 1): return ("四等奖", 200)
        case (4, 0), (3, 1): return ("五等奖", 10)
        case (_, 1) where r <= 2: return ("六等奖", 5)
        default: return (nil, 0)
        }
    }

    static func dltTier(f: Int, k: Int) -> (String?, Int?) {
        switch (f, k) {
        case (5, 2): return ("一等奖", nil)
        case (5, 1): return ("二等奖", nil)
        case (5, 0): return ("三等奖", 10000)
        case (4, 2): return ("四等奖", 3000)
        case (4, 1): return ("五等奖", 300)
        case (3, 2): return ("六等奖", 200)
        case (4, 0): return ("七等奖", 100)
        case (3, 1), (2, 2): return ("八等奖", 15)
        case (3, 0), (2, 1), (1, 2), (0, 2): return ("九等奖", 5)
        default: return (nil, 0)
        }
    }
}
