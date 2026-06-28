import Foundation
import SwiftData

@MainActor
public final class Store {
    public let container: ModelContainer
    public var context: ModelContext { container.mainContext }

    public init(inMemory: Bool = false) throws {
        let schema = Schema([Ticket.self, VerificationRecord.self, Draw.self, DrawVersion.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        self.container = try ModelContainer(for: schema, configurations: [config])
    }

    public func save() { try? context.save() }

    public func createOrGetDraw(category: Category, issue: String, source: DataSourceKind) -> Draw {
        let cat = category.rawValue, src = source.rawValue
        let predicate = #Predicate<Draw> { $0.category == cat && $0.issue == issue && $0.source == src }
        if let found = try? context.fetch(FetchDescriptor<Draw>(predicate: predicate)).first {
            return found
        }
        let draw = Draw(category: cat, issue: issue, source: src)
        context.insert(draw)
        save()
        return draw
    }

    public func latestVersion(_ draw: Draw) -> DrawVersion? {
        draw.versions.max(by: { $0.versionNumber < $1.versionNumber })
    }

    @discardableResult
    public func addVersion(to draw: Draw, front: [Int], back: [Int], prizes: [String: Int]?,
                           drawDate: Date?, origin: String, sourceURL: String?) -> DrawVersion {
        let next = (latestVersion(draw)?.versionNumber ?? 0) + 1
        let v = DrawVersion(versionNumber: next, frontNumbers: front, backNumbers: back,
                            prizes: prizes, drawDate: drawDate, origin: origin, sourceURL: sourceURL, draw: draw)
        context.insert(v)
        draw.versions.append(v)
        save()
        return v
    }

    @discardableResult
    public func saveTicket(category: Category, issue: String, bets: [Bet],
                           imageFileName: String?, cost: Double, purchaseDate: Date) -> Ticket {
        let t = Ticket(category: category.rawValue, issue: issue, bets: bets,
                       imageFileName: imageFileName, cost: cost, purchaseDate: purchaseDate)
        context.insert(t)
        save()
        return t
    }

    @discardableResult
    public func addVerification(ticket: Ticket, drawVersion: DrawVersion,
                                results: [BetResultSnapshot], totalAmount: Int) -> VerificationRecord {
        let rec = VerificationRecord(totalAmount: totalAmount, results: results,
                                     ticket: ticket, drawVersion: drawVersion)
        context.insert(rec)
        ticket.verifications.append(rec)
        save()
        return rec
    }

    public func allTickets() -> [Ticket] {
        let descriptor = FetchDescriptor<Ticket>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    public func allDraws() -> [Draw] {
        let descriptor = FetchDescriptor<Draw>(
            sortBy: [
                SortDescriptor(\.issue, order: .reverse),
                SortDescriptor(\.category),
                SortDescriptor(\.source),
            ]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
