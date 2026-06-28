import Foundation

public enum PrizeAmountParser {
    public enum Error: Swift.Error, Equatable, LocalizedError, Sendable {
        case invalidAmount(String)

        public var errorDescription: String? {
            switch self {
            case .invalidAmount(let text):
                return "奖金金额格式无效：\(text)"
            }
        }
    }

    public static func parse(_ text: String) throws -> Int {
        let original = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var normalized = original
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "，", with: "")
        var multiplier = Decimal(1)
        var allowsDecimal = false

        if normalized.hasSuffix("万元") {
            normalized.removeLast(2)
            multiplier = Decimal(10_000)
            allowsDecimal = true
        } else if normalized.hasSuffix("万") {
            normalized.removeLast()
            multiplier = Decimal(10_000)
            allowsDecimal = true
        } else if normalized.hasSuffix("元") {
            normalized.removeLast()
        }

        guard !normalized.isEmpty else { throw Error.invalidAmount(original) }
        guard isValidNumberText(normalized, allowsDecimal: allowsDecimal) else {
            throw Error.invalidAmount(original)
        }
        guard let amount = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else {
            throw Error.invalidAmount(original)
        }

        let yuanAmount = amount * multiplier
        var value = yuanAmount
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        guard rounded == yuanAmount else { throw Error.invalidAmount(original) }

        return NSDecimalNumber(decimal: rounded).intValue
    }

    private static func isValidNumberText(_ text: String, allowsDecimal: Bool) -> Bool {
        var dotCount = 0
        for character in text {
            if character.isNumber {
                continue
            }
            if allowsDecimal && character == "." {
                dotCount += 1
                if dotCount > 1 { return false }
                continue
            }
            return false
        }
        return text.first != "." && text.last != "."
    }
}
