public enum DataSourceKind: String, Codable, CaseIterable, Sendable {
    case officialSporttery, officialCWL, webService, manual

    public var displayName: String {
        switch self {
        case .officialSporttery: return "官方·体彩"
        case .officialCWL: return "官方·福彩"
        case .webService: return "Web 服务"
        case .manual: return "手动录入"
        }
    }

    public var category: Category? {
        switch self {
        case .officialSporttery: return .dlt
        case .officialCWL: return .ssq
        case .webService, .manual: return nil
        }
    }
}
