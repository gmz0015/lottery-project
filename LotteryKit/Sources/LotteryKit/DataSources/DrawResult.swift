import Foundation

public struct DrawResult: Equatable, Sendable {
    public let category: Category
    public let issue: String
    public let frontNumbers: [Int]
    public let backNumbers: [Int]
    public let drawDate: Date?
    public let prizes: [String: Int]?
    public let source: DataSourceKind
    public let sourceURL: String?

    public init(category: Category, issue: String, frontNumbers: [Int], backNumbers: [Int],
                drawDate: Date?, prizes: [String: Int]?, source: DataSourceKind, sourceURL: String?) {
        self.category = category
        self.issue = issue
        self.frontNumbers = frontNumbers
        self.backNumbers = backNumbers
        self.drawDate = drawDate
        self.prizes = prizes
        self.source = source
        self.sourceURL = sourceURL
    }
}

public enum DrawSourceError: Error, Equatable {
    case notFound
    case badResponse(String)
}

public protocol DrawDataSource: Sendable {
    var kind: DataSourceKind { get }
    func fetchDraw(category: Category, issue: String) async throws -> DrawResult
}

enum NumParse {
    static func ints(_ s: String, separators: CharacterSet) -> [Int] {
        s.components(separatedBy: separators).compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }
    static func date(_ s: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: String(s.prefix(10)))
    }
}
