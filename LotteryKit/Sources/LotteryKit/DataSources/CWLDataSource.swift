import Foundation

public struct CWLDataSource: DrawDataSource {
    public let kind: DataSourceKind = .officialCWL
    public init() {}

    static let tierNames = [1: "一等奖", 2: "二等奖", 3: "三等奖", 4: "四等奖", 5: "五等奖", 6: "六等奖"]
    static func endpoint(issue: String) -> URL {
        URL(string: "http://www.cwl.gov.cn/cwl_admin/front/cwlkj/search/kjxx/findDrawNotice?name=ssq&issueStart=\(issue)&issueEnd=\(issue)&pageNo=1&pageSize=10&systemType=PC")!
    }
    static func pageURL(issue: String) -> String { "http://www.cwl.gov.cn/kjxx/ssq/kjgg/" }

    public static func parse(_ data: Data, issue: String) throws -> DrawResult {
        struct Resp: Decodable {
            struct Item: Decodable {
                let code: String; let red: String; let blue: String
                let date: String?; let prizegrades: [Grade]?
            }
            struct Grade: Decodable { let type: Int; let typemoney: String? }
            let result: [Item]
        }
        let resp: Resp
        do {
            resp = try JSONDecoder().decode(Resp.self, from: data)
        } catch {
            throw DrawSourceError.badResponse("官方福彩返回内容不是有效开奖数据，请稍后重试或使用手动录入。")
        }
        guard let item = resp.result.first(where: { $0.code == issue }) ?? resp.result.first else {
            throw DrawSourceError.notFound
        }
        let front = NumParse.ints(item.red, separators: CharacterSet(charactersIn: ", "))
        let back = NumParse.ints(item.blue, separators: CharacterSet(charactersIn: ", "))
        guard front.count == 6, back.count == 1 else { throw DrawSourceError.badResponse("号码个数异常") }
        var prizes: [String: Int] = [:]
        for g in item.prizegrades ?? [] {
            if let name = tierNames[g.type], let m = g.typemoney, let v = Int(m.replacingOccurrences(of: ",", with: "")) {
                prizes[name] = v
            }
        }
        return DrawResult(category: .ssq, issue: item.code, frontNumbers: front, backNumbers: back,
                          drawDate: item.date.flatMap(NumParse.date),
                          prizes: prizes.isEmpty ? nil : prizes,
                          source: .officialCWL, sourceURL: pageURL(issue: issue))
    }

    public func fetchDraw(category: Category, issue: String) async throws -> DrawResult {
        var req = URLRequest(url: Self.endpoint(issue: issue))
        req.setValue("Mozilla/5.0 (Macintosh)", forHTTPHeaderField: "User-Agent")
        req.setValue("http://www.cwl.gov.cn/", forHTTPHeaderField: "Referer")
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw DrawSourceError.badResponse("官方福彩接口返回 HTTP \(http.statusCode)，可能被风控拦截；请稍后重试或使用手动录入。")
        }
        return try Self.parse(data, issue: issue)
    }
}
