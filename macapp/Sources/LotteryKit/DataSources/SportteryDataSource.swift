import Foundation

public struct SportteryDataSource: DrawDataSource {
    public let kind: DataSourceKind = .officialSporttery
    public init() {}

    static func endpoint(issue: String) -> URL {
        URL(string: "https://webapi.sporttery.cn/gateway/lottery/getHistoryPageListV1.qry?gameNo=85&provinceId=0&pageSize=30&isVerify=1&pageNo=1")!
    }
    static func pageURL(issue: String) -> String {
        "https://www.sporttery.cn/kj/kjgg/"
    }

    public static func parse(_ data: Data, issue: String) throws -> DrawResult {
        struct Resp: Decodable {
            struct Value: Decodable { let list: [Item] }
            struct Item: Decodable {
                let lotteryDrawNum: String
                let lotteryDrawResult: String
                let lotteryDrawTime: String?
                let prizeLevelList: [Prize]?
            }
            struct Prize: Decodable { let prizeLevel: String; let stakeAmount: String? }
            let value: Value
        }
        let resp = try JSONDecoder().decode(Resp.self, from: data)
        guard let item = resp.value.list.first(where: { $0.lotteryDrawNum == issue }) ?? resp.value.list.first else {
            throw DrawSourceError.notFound
        }
        let nums = NumParse.ints(item.lotteryDrawResult, separators: .whitespaces)
        guard nums.count == 7 else { throw DrawSourceError.badResponse("号码个数异常") }
        var prizes: [String: Int] = [:]
        for p in item.prizeLevelList ?? [] {
            if let a = p.stakeAmount, let v = Int(a.replacingOccurrences(of: ",", with: "")) { prizes[p.prizeLevel] = v }
        }
        return DrawResult(category: .dlt, issue: item.lotteryDrawNum,
                          frontNumbers: Array(nums.prefix(5)), backNumbers: Array(nums.suffix(2)),
                          drawDate: item.lotteryDrawTime.flatMap(NumParse.date),
                          prizes: prizes.isEmpty ? nil : prizes,
                          source: .officialSporttery, sourceURL: pageURL(issue: issue))
    }

    public func fetchDraw(category: Category, issue: String) async throws -> DrawResult {
        var req = URLRequest(url: Self.endpoint(issue: issue))
        req.setValue("Mozilla/5.0 (Macintosh)", forHTTPHeaderField: "User-Agent")
        req.setValue("https://static.sporttery.cn/", forHTTPHeaderField: "Referer")
        let (data, _) = try await URLSession.shared.data(for: req)
        return try Self.parse(data, issue: issue)
    }
}
