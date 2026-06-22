import Foundation

public struct TicketStat: Sendable {
    public let ticket: Ticket
    public let latest: VerificationRecord?
}

public struct StatsSummary: Equatable, Sendable {
    public let totalCost: Double
    public let totalWin: Int
    public let net: Double
    public let winRate: Double
    public let ticketCount: Int
}

public enum StatsService {
    public static func latestVerifications(_ tickets: [Ticket]) -> [TicketStat] {
        tickets.map { t in
            TicketStat(ticket: t, latest: t.verifications.max(by: { $0.createdAt < $1.createdAt }))
        }
    }

    public static func summary(_ stats: [TicketStat]) -> StatsSummary {
        let totalCost = stats.reduce(0.0) { $0 + $1.ticket.cost }
        let totalWin = stats.reduce(0) { $0 + ($1.latest?.totalAmount ?? 0) }
        let wins = stats.filter { ($0.latest?.totalAmount ?? 0) > 0 }.count
        let count = stats.count
        return StatsSummary(totalCost: totalCost, totalWin: totalWin,
                            net: Double(totalWin) - totalCost,
                            winRate: count == 0 ? 0 : Double(wins) / Double(count),
                            ticketCount: count)
    }

    public static func purchasesByDay(_ tickets: [Ticket]) -> [Date: Int] {
        var out: [Date: Int] = [:]
        let cal = Calendar.current
        for t in tickets {
            let day = cal.startOfDay(for: t.purchaseDate)
            out[day, default: 0] += 1
        }
        return out
    }

    public static func countByCategory(_ tickets: [Ticket]) -> [Category: Int] {
        var out: [Category: Int] = [:]
        for t in tickets {
            if let c = Category(rawValue: t.category) { out[c, default: 0] += 1 }
        }
        return out
    }

    public static func myNumberFrequency(_ tickets: [Ticket], category: Category) -> [Int: Int] {
        var out: [Int: Int] = [:]
        for t in tickets where t.category == category.rawValue {
            for bet in t.bets {
                for n in bet.front { out[n, default: 0] += 1 }
            }
        }
        return out
    }
}
