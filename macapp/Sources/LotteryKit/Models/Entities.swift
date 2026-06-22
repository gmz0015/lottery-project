import Foundation
import SwiftData

public struct BetResultSnapshot: Codable, Equatable, Sendable {
    public var bet: Bet
    public var result: BetResult
    public init(bet: Bet, result: BetResult) {
        self.bet = bet
        self.result = result
    }
}

@Model
public final class Ticket {
    @Attribute(.unique) public var id: UUID
    public var category: String
    public var issue: String
    public var bets: [Bet]
    public var imageFileName: String?
    public var cost: Double
    public var purchaseDate: Date
    public var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \VerificationRecord.ticket)
    public var verifications: [VerificationRecord]

    public init(id: UUID = UUID(), category: String, issue: String, bets: [Bet],
                imageFileName: String?, cost: Double, purchaseDate: Date, createdAt: Date = Date()) {
        self.id = id
        self.category = category
        self.issue = issue
        self.bets = bets
        self.imageFileName = imageFileName
        self.cost = cost
        self.purchaseDate = purchaseDate
        self.createdAt = createdAt
        self.verifications = []
    }
}

@Model
public final class VerificationRecord {
    @Attribute(.unique) public var id: UUID
    public var createdAt: Date
    public var totalAmount: Int
    public var results: [BetResultSnapshot]
    public var ticket: Ticket?
    public var drawVersion: DrawVersion?

    public init(id: UUID = UUID(), createdAt: Date = Date(), totalAmount: Int,
                results: [BetResultSnapshot], ticket: Ticket?, drawVersion: DrawVersion?) {
        self.id = id
        self.createdAt = createdAt
        self.totalAmount = totalAmount
        self.results = results
        self.ticket = ticket
        self.drawVersion = drawVersion
    }
}

@Model
public final class Draw {
    @Attribute(.unique) public var id: UUID
    public var category: String
    public var issue: String
    public var source: String
    @Relationship(deleteRule: .cascade, inverse: \DrawVersion.draw)
    public var versions: [DrawVersion]

    public init(id: UUID = UUID(), category: String, issue: String, source: String) {
        self.id = id
        self.category = category
        self.issue = issue
        self.source = source
        self.versions = []
    }
}

@Model
public final class DrawVersion {
    @Attribute(.unique) public var id: UUID
    public var versionNumber: Int
    public var frontNumbers: [Int]
    public var backNumbers: [Int]
    public var prizes: [String: Int]?
    public var drawDate: Date?
    public var origin: String
    public var sourceURL: String?
    public var createdAt: Date
    public var draw: Draw?

    public init(id: UUID = UUID(), versionNumber: Int, frontNumbers: [Int], backNumbers: [Int],
                prizes: [String: Int]?, drawDate: Date?, origin: String, sourceURL: String?,
                createdAt: Date = Date(), draw: Draw?) {
        self.id = id
        self.versionNumber = versionNumber
        self.frontNumbers = frontNumbers
        self.backNumbers = backNumbers
        self.prizes = prizes
        self.drawDate = drawDate
        self.origin = origin
        self.sourceURL = sourceURL
        self.createdAt = createdAt
        self.draw = draw
    }
}
