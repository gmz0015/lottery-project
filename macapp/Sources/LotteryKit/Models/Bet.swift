public struct Bet: Codable, Equatable, Hashable, Sendable {
    public var front: [Int]
    public var back: [Int]
    public init(front: [Int], back: [Int]) {
        self.front = front
        self.back = back
    }
}
