import Foundation

public enum DrawEntryError: Error, Equatable, LocalizedError, Sendable {
    case emptyIssue
    case emptyNumbers
    case invalidNumbers(String)

    public var errorDescription: String? {
        switch self {
        case .emptyIssue:
            return "请填写期号"
        case .emptyNumbers:
            return "请填写开奖号码"
        case .invalidNumbers(let message):
            return message
        }
    }
}

@MainActor
public struct DrawEntryService {
    private let store: Store

    public init(store: Store) {
        self.store = store
    }

    @discardableResult
    public func saveManualEntry(category: Category,
                                issue: String,
                                frontText: String,
                                backText: String,
                                drawDate: Date?,
                                prizes: [String: Int]?) throws -> DrawVersion {
        let normalizedIssue = issue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedIssue.isEmpty else { throw DrawEntryError.emptyIssue }

        let front = try Self.parseNumbers(frontText)
        let back = try Self.parseNumbers(backText)
        guard !front.isEmpty, !back.isEmpty else { throw DrawEntryError.emptyNumbers }

        if let message = NumberValidation.validate(category: category, front: front, back: back) {
            throw DrawEntryError.invalidNumbers(message)
        }

        let draw = store.createOrGetDraw(category: category, issue: normalizedIssue, source: .manual)
        return store.addVersion(to: draw,
                                front: front,
                                back: back,
                                prizes: prizes,
                                drawDate: drawDate,
                                origin: "manual",
                                sourceURL: nil)
    }

    private static func parseNumbers(_ text: String) throws -> [Int] {
        try text.split(whereSeparator: { character in
            character.isWhitespace || character == "," || character == "，"
        })
        .map { token in
            guard let number = Int(token) else {
                throw DrawEntryError.invalidNumbers("号码包含非数字内容：\(token)")
            }
            return number
        }
    }
}
