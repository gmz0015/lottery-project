import Foundation

public enum BetTextParser {
    public enum Error: Swift.Error, Equatable, LocalizedError, Sendable {
        case empty
        case lineCountMismatch(front: Int, back: Int)
        case invalidBet(line: Int, message: String)

        public var errorDescription: String? {
            switch self {
            case .empty:
                return "请填写号码"
            case .lineCountMismatch(let front, let back):
                return "前区/红球与后区/蓝球行数不一致（\(front) 行 vs \(back) 行）"
            case .invalidBet(let line, let message):
                return "第 \(line) 注：\(message)"
            }
        }
    }

    public static func parse(category: Category, frontText: String, backText: String) throws -> [Bet] {
        let frontLines = numberLines(frontText)
        let backLines = numberLines(backText)
        guard !frontLines.isEmpty, !backLines.isEmpty else { throw Error.empty }
        guard frontLines.count == backLines.count else {
            throw Error.lineCountMismatch(front: frontLines.count, back: backLines.count)
        }

        var bets: [Bet] = []
        for index in frontLines.indices {
            let front = parseNumbers(frontLines[index])
            let back = parseNumbers(backLines[index])
            if let message = NumberValidation.validateBet(category: category, front: front, back: back) {
                throw Error.invalidBet(line: index + 1, message: message)
            }
            bets.append(Bet(front: front, back: back))
        }
        return bets
    }

    private static func numberLines(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func parseNumbers(_ text: String) -> [Int] {
        text.split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == "，" })
            .compactMap { Int($0) }
    }
}
