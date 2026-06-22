import Foundation

public struct WebServiceDataSource: DrawDataSource {
    public let kind: DataSourceKind = .webService
    public let baseURL: String
    public let token: String
    public init(baseURL: String, token: String) {
        self.baseURL = baseURL
        self.token = token
    }

    static func path(category: Category, issue: String) -> String {
        "/api/v1/draws/\(category.rawValue)/\(issue)"
    }

    public static func parse(_ data: Data, baseURL: String) throws -> DrawResult {
        struct Resp: Decodable {
            let category: String; let issue: String
            let frontNumbers: [Int]; let backNumbers: [Int]
            let drawDate: String?; let prizes: [String: Int]?
        }
        let r = try JSONDecoder().decode(Resp.self, from: data)
        guard let cat = Category(rawValue: r.category) else { throw DrawSourceError.badResponse("未知彩种") }
        let url = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + path(category: cat, issue: r.issue)
        return DrawResult(category: cat, issue: r.issue, frontNumbers: r.frontNumbers, backNumbers: r.backNumbers,
                          drawDate: r.drawDate.flatMap(NumParse.date), prizes: r.prizes,
                          source: .webService, sourceURL: url)
    }

    public func fetchDraw(category: Category, issue: String) async throws -> DrawResult {
        let base = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + Self.path(category: category, issue: issue)) else {
            throw DrawSourceError.badResponse("无效 Base URL")
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode == 404 { throw DrawSourceError.notFound }
        return try Self.parse(data, baseURL: baseURL)
    }
}
