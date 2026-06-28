import XCTest
@testable import LotteryKit

private struct FakeSource: DrawDataSource {
    let kind: DataSourceKind
    let result: DrawResult
    func fetchDraw(category: LotteryKit.Category, issue: String) async throws -> DrawResult { result }
}

@MainActor
final class DrawFetchServiceTests: XCTestCase {
    func makeResult(_ back: [Int]) -> DrawResult {
        DrawResult(category: .ssq, issue: "24001", frontNumbers: [1,2,3,4,5,6], backNumbers: back,
                   drawDate: nil, prizes: nil, source: .webService, sourceURL: "u")
    }

    func testFetchCreatesV1ThenCacheHit() async throws {
        let store = try Store(inMemory: true)
        let svc = DrawFetchService(store: store, sources: [.webService: FakeSource(kind: .webService, result: makeResult([16]))])
        let v1 = try await svc.fetch(category: .ssq, issue: "24001", source: .webService, forceRefresh: false)
        XCTAssertEqual(v1.versionNumber, 1)
        XCTAssertNotNil(svc.cachedLatest(category: .ssq, issue: "24001", source: .webService))
        let again = try await svc.fetch(category: .ssq, issue: "24001", source: .webService, forceRefresh: false)
        XCTAssertEqual(again.id, v1.id)  // 缓存命中, 不新增
    }

    func testForceRefreshAddsVersionWhenNumbersChange() async throws {
        let store = try Store(inMemory: true)
        let svc = DrawFetchService(store: store, sources: [.webService: FakeSource(kind: .webService, result: makeResult([16]))])
        _ = try await svc.fetch(category: .ssq, issue: "24001", source: .webService, forceRefresh: false)
        let svc2 = DrawFetchService(store: store, sources: [.webService: FakeSource(kind: .webService, result: makeResult([10]))])
        let v2 = try await svc2.fetch(category: .ssq, issue: "24001", source: .webService, forceRefresh: true)
        XCTAssertEqual(v2.versionNumber, 2)
        XCTAssertEqual(v2.backNumbers, [10])
    }

    func testRecordManualVersionCreatesManualDrawAndReusesMatchingLatest() throws {
        let store = try Store(inMemory: true)
        let svc = DrawFetchService(store: store, sources: [:])

        let v1 = svc.recordManual(category: .ssq, issue: "24001",
                                  front: [1,2,3,4,5,6], back: [16], prizes: nil)
        let again = svc.recordManual(category: .ssq, issue: "24001",
                                     front: [1,2,3,4,5,6], back: [16], prizes: nil)
        let v2 = svc.recordManual(category: .ssq, issue: "24001",
                                  front: [1,2,3,4,5,7], back: [16], prizes: nil)

        XCTAssertEqual(v1.draw?.source, DataSourceKind.manual.rawValue)
        XCTAssertEqual(again.id, v1.id)
        XCTAssertEqual(v2.versionNumber, 2)
        XCTAssertEqual(svc.cachedLatest(category: .ssq, issue: "24001", source: .manual)?.id, v2.id)
    }
}
