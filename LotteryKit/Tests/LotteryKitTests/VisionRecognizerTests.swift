import XCTest
@testable import LotteryKit

final class VisionRecognizerTests: XCTestCase {
    func testParsePlainJSON() throws {
        let content = #"{"category":"ssq","issue":"24001","bets":[{"front":[1,2,3,4,5,6],"back":[16]}]}"#
        let t = try OpenAIVisionRecognizer.parseContent(content)
        XCTAssertEqual(t.category, .ssq)
        XCTAssertEqual(t.issue, "24001")
        XCTAssertEqual(t.bets, [Bet(front: [1,2,3,4,5,6], back: [16])])
    }

    func testParseFencedJSON() throws {
        let content = "```json\n{\"category\":\"dlt\",\"issue\":\"24002\",\"bets\":[{\"front\":[1,2,3,4,5],\"back\":[1,2]}]}\n```"
        let t = try OpenAIVisionRecognizer.parseContent(content)
        XCTAssertEqual(t.category, .dlt)
        XCTAssertEqual(t.bets.first?.back, [1,2])
    }

    func testBadOutputThrows() {
        XCTAssertThrowsError(try OpenAIVisionRecognizer.parseContent("抱歉我无法识别"))
    }

    func testEndpointURLAddsHTTPSWhenSchemeIsMissing() throws {
        let url = try OpenAIVisionRecognizer.endpointURL(from: "api.example.com/v1")

        XCTAssertEqual(url.absoluteString, "https://api.example.com/v1/chat/completions")
    }

    func testEndpointURLTrimsWhitespaceAndTrailingSlashes() throws {
        let url = try OpenAIVisionRecognizer.endpointURL(from: " https://api.example.com/v1/// ")

        XCTAssertEqual(url.absoluteString, "https://api.example.com/v1/chat/completions")
    }

    func testEndpointURLDoesNotDuplicateChatCompletionsPath() throws {
        let url = try OpenAIVisionRecognizer.endpointURL(from: "https://api.example.com/v1/chat/completions")

        XCTAssertEqual(url.absoluteString, "https://api.example.com/v1/chat/completions")
    }

    func testEndpointURLRejectsBaseURLWithoutHost() {
        XCTAssertThrowsError(try OpenAIVisionRecognizer.endpointURL(from: "https:///v1")) { error in
            XCTAssertEqual(error as? RecognizerError, .notConfigured)
        }
    }
}
