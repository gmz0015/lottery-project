import Foundation

public struct RecognizedTicket: Equatable, Sendable {
    public let category: Category
    public let issue: String
    public let bets: [Bet]
    public init(category: Category, issue: String, bets: [Bet]) {
        self.category = category
        self.issue = issue
        self.bets = bets
    }
}

public enum RecognizerError: Error, Equatable {
    case notConfigured
    case badOutput(String)
}

public protocol VisionRecognizer: Sendable {
    func recognize(imageData: Data) async throws -> RecognizedTicket
}

public struct OpenAIVisionRecognizer: VisionRecognizer {
    public let baseURL: String
    public let apiKey: String
    public let model: String
    public init(baseURL: String, apiKey: String, model: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
    }

    static let prompt = """
    你是彩票识别助手。识别图片中的中国福利彩票双色球(ssq)或体育彩票大乐透(dlt)。\
    只输出严格 JSON，不要任何解释或代码块标记，格式：\
    {"category":"ssq|dlt","issue":"期号","bets":[{"front":[红球/前区数字],"back":[蓝球/后区数字]}]}。\
    双色球 front 为6个红球(1-33) back 为1个蓝球(1-16)；大乐透 front 为5个前区(1-35) back 为2个后区(1-12)。
    """

    public static func parseContent(_ content: String) throws -> RecognizedTicket {
        var text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else {
            throw RecognizerError.badOutput(content)
        }
        let jsonStr = String(text[start...end])
        struct Raw: Decodable {
            let category: String; let issue: String
            struct B: Decodable { let front: [Int]; let back: [Int] }
            let bets: [B]
        }
        guard let data = jsonStr.data(using: .utf8),
              let raw = try? JSONDecoder().decode(Raw.self, from: data),
              let cat = Category(rawValue: raw.category) else {
            throw RecognizerError.badOutput(content)
        }
        return RecognizedTicket(category: cat, issue: raw.issue,
                                bets: raw.bets.map { Bet(front: $0.front, back: $0.back) })
    }

    public func recognize(imageData: Data) async throws -> RecognizedTicket {
        guard !baseURL.isEmpty, !apiKey.isEmpty, !model.isEmpty else { throw RecognizerError.notConfigured }
        let base = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + "/chat/completions") else { throw RecognizerError.notConfigured }
        let b64 = imageData.base64EncodedString()
        let body: [String: Any] = [
            "model": model,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "text", "text": Self.prompt],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(b64)"]],
                ],
            ]],
            "temperature": 0,
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        struct ChatResp: Decodable {
            struct Choice: Decodable { struct Msg: Decodable { let content: String }; let message: Msg }
            let choices: [Choice]
        }
        guard let resp = try? JSONDecoder().decode(ChatResp.self, from: data),
              let content = resp.choices.first?.message.content else {
            throw RecognizerError.badOutput(String(data: data, encoding: .utf8) ?? "无响应")
        }
        return try Self.parseContent(content)
    }
}
