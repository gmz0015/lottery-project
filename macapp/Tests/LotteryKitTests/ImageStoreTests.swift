import XCTest
@testable import LotteryKit

final class ImageStoreTests: XCTestCase {
    func testSaveAndLoadRoundtrip() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = ImageStore(directory: tmp)
        let data = Data([0xFF, 0xD8, 0xFF, 0x00, 0x01])
        let name = try store.save(data, ext: "jpg")
        XCTAssertTrue(name.hasSuffix(".jpg"))
        XCTAssertEqual(store.load(name), data)
        XCTAssertNil(store.load("missing.jpg"))
    }
}
