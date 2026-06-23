import XCTest
@testable import LotteryKit

final class AppSettingsTests: XCTestCase {
    func makeDefaults() -> UserDefaults {
        let d = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        return d
    }

    func testRoundtrip() {
        let d = makeDefaults()
        let s = AppSettings(defaults: d)
        s.modelBaseURL = "https://api.x.com/v1"
        s.modelName = "gpt-4o"
        s.webServiceEnabled = true
        s.sourcePriority = [.webService, .officialCWL]
        let s2 = AppSettings(defaults: d)
        XCTAssertEqual(s2.modelBaseURL, "https://api.x.com/v1")
        XCTAssertEqual(s2.modelName, "gpt-4o")
        XCTAssertTrue(s2.webServiceEnabled)
        XCTAssertEqual(s2.sourcePriority, [.webService, .officialCWL])
    }
}
