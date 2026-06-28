import XCTest
@testable import LotteryKit

@MainActor
final class DrawEntryServiceTests: XCTestCase {
    func testSaveManualEntryParsesNumbersAndCreatesManualDraw() throws {
        let store = try Store(inMemory: true)
        let service = DrawEntryService(store: store)

        let version = try service.saveManualEntry(category: .ssq,
                                                  issue: "2026070",
                                                  frontText: "01 02,03，04 05 06",
                                                  backText: "16",
                                                  drawDate: nil,
                                                  prizes: ["一等奖": 5_000_000])

        XCTAssertEqual(version.versionNumber, 1)
        XCTAssertEqual(version.frontNumbers, [1, 2, 3, 4, 5, 6])
        XCTAssertEqual(version.backNumbers, [16])
        XCTAssertEqual(version.origin, "manual")
        XCTAssertEqual(version.prizes?["一等奖"], 5_000_000)
        XCTAssertEqual(store.allDraws().first?.source, DataSourceKind.manual.rawValue)
    }

    func testSaveManualEntryRejectsInvalidNumbersWithoutCreatingDraw() throws {
        let store = try Store(inMemory: true)
        let service = DrawEntryService(store: store)

        XCTAssertThrowsError(try service.saveManualEntry(category: .dlt,
                                                         issue: "2026070",
                                                         frontText: "01 02 03 04 36",
                                                         backText: "01 12",
                                                         drawDate: nil,
                                                         prizes: nil)) { error in
            XCTAssertEqual(error as? DrawEntryError, .invalidNumbers("前区/红球范围应为 1-35"))
        }
        XCTAssertTrue(store.allDraws().isEmpty)
    }

    func testSaveManualEntryRejectsNonNumericNumberTokenWithoutCreatingDraw() throws {
        let store = try Store(inMemory: true)
        let service = DrawEntryService(store: store)

        XCTAssertThrowsError(try service.saveManualEntry(category: .ssq,
                                                         issue: "2026070",
                                                         frontText: "01 02 03 04 05 06x 07",
                                                         backText: "16",
                                                         drawDate: nil,
                                                         prizes: nil)) { error in
            XCTAssertEqual(error as? DrawEntryError, .invalidNumbers("号码包含非数字内容：06x"))
        }
        XCTAssertTrue(store.allDraws().isEmpty)
    }

    func testPrizeAmountParserSupportsYuanAndWanAmounts() throws {
        XCTAssertEqual(try PrizeAmountParser.parse("5000000"), 5_000_000)
        XCTAssertEqual(try PrizeAmountParser.parse("5,000,000"), 5_000_000)
        XCTAssertEqual(try PrizeAmountParser.parse("500万"), 5_000_000)
        XCTAssertEqual(try PrizeAmountParser.parse("1.5万"), 15_000)
    }

    func testPrizeAmountParserRejectsInvalidMixedText() {
        XCTAssertThrowsError(try PrizeAmountParser.parse("奖金500万")) { error in
            XCTAssertEqual(error as? PrizeAmountParser.Error, .invalidAmount("奖金500万"))
        }
    }
}
