public enum Category: String, Codable, CaseIterable, Sendable {
    case ssq, dlt

    public var displayName: String { self == .ssq ? "双色球" : "大乐透" }
    public var frontCount: Int { self == .ssq ? 6 : 5 }
    public var frontMax: Int { self == .ssq ? 33 : 35 }
    public var backCount: Int { self == .ssq ? 1 : 2 }
    public var backMax: Int { self == .ssq ? 16 : 12 }
}
