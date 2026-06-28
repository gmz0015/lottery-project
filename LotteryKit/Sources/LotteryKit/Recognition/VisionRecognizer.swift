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
    case requestFailed(String)
}

extension RecognizerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "请先在设置中配置模型 Base URL、API Key 和模型名"
        case .badOutput(let content):
            return "模型返回内容无法解析：\(content)"
        case .requestFailed(let message):
            return message
        }
    }
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
    每一组投注输出一个 bets 元素；复式投注不要拆开组合，保留在同一元素中，front/back 可以多于单式号码个数。\
    双色球单式 front 为6个红球(1-33) back 为1个蓝球(1-16)；大乐透单式 front 为5个前区(1-35) back 为2个后区(1-12)。
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

    static func endpointURL(from baseURL: String) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw RecognizerError.notConfigured }

        let withoutTrailingSlashes = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalized: String
        if withoutTrailingSlashes.contains("://") {
            normalized = withoutTrailingSlashes
        } else {
            let lowercased = withoutTrailingSlashes.lowercased()
            let defaultScheme = lowercased.hasPrefix("localhost")
                || lowercased.hasPrefix("127.")
                || lowercased.hasPrefix("[::1]") ? "http" : "https"
            normalized = "\(defaultScheme)://\(withoutTrailingSlashes)"
        }

        guard var components = URLComponents(string: normalized),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host,
              !host.isEmpty else {
            throw RecognizerError.notConfigured
        }

        var path = components.percentEncodedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.isEmpty {
            path = "chat/completions"
        } else if !path.hasSuffix("chat/completions") {
            path += "/chat/completions"
        }
        components.percentEncodedPath = "/" + path
        components.query = nil
        components.fragment = nil

        guard let url = components.url else { throw RecognizerError.notConfigured }
        return url
    }

    public func recognize(imageData: Data) async throws -> RecognizedTicket {
        guard !baseURL.isEmpty, !apiKey.isEmpty, !model.isEmpty else { throw RecognizerError.notConfigured }
        let url = try Self.endpointURL(from: baseURL)
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
        let data: Data
        do {
            let (responseData, _) = try await URLSession.shared.data(for: req)
            data = responseData
        } catch {
            throw RecognizerError.requestFailed("模型请求失败：请检查 Base URL 是否正确、网络是否可用、域名是否能解析（\(error.localizedDescription)）")
        }
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
