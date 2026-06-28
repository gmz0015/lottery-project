public struct Bet: Codable, Equatable, Hashable, Sendable {
    public var front: [Int]
    public var back: [Int]
    public init(front: [Int], back: [Int]) {
        self.front = front
        self.back = back
    }

    public func expandedSingles(category: Category) -> [Bet] {
        let frontCombinations = Self.combinations(front, taking: category.frontCount)
        let backCombinations = Self.combinations(back, taking: category.backCount)
        var singles: [Bet] = []
        for front in frontCombinations {
            for back in backCombinations {
                singles.append(Bet(front: front, back: back))
            }
        }
        return singles
    }

    public func singleBetCount(category: Category) -> Int {
        expandedSingles(category: category).count
    }

    private static func combinations(_ values: [Int], taking count: Int) -> [[Int]] {
        guard count > 0, values.count >= count else { return [] }
        if count == values.count { return [values] }

        var result: [[Int]] = []
        var current: [Int] = []

        func visit(start: Int, remaining: Int) {
            if remaining == 0 {
                result.append(current)
                return
            }
            let lastStart = values.count - remaining
            guard start <= lastStart else { return }
            for index in start...lastStart {
                current.append(values[index])
                visit(start: index + 1, remaining: remaining - 1)
                current.removeLast()
            }
        }

        visit(start: 0, remaining: count)
        return result
    }
}
