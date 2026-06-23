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
}
