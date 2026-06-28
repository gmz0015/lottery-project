import Foundation
import SwiftData

@MainActor
public final class DrawFetchService {
    private let store: Store
    private let sources: [DataSourceKind: DrawDataSource]

    public init(store: Store, sources: [DataSourceKind: DrawDataSource]) {
        self.store = store
        self.sources = sources
    }

    public func cachedLatest(category: Category, issue: String, source: DataSourceKind) -> DrawVersion? {
        let cat = category.rawValue, src = source.rawValue
        let predicate = #Predicate<Draw> { $0.category == cat && $0.issue == issue && $0.source == src }
        guard let draw = try? store.context.fetch(FetchDescriptor<Draw>(predicate: predicate)).first else { return nil }
        return store.latestVersion(draw)
    }

    public func fetch(category: Category, issue: String, source: DataSourceKind,
                      forceRefresh: Bool) async throws -> DrawVersion {
        if !forceRefresh, let cached = cachedLatest(category: category, issue: issue, source: source) {
            return cached
        }
        guard let ds = sources[source] else { throw DrawSourceError.badResponse("数据源未配置: \(source.displayName)") }
        let result = try await ds.fetchDraw(category: category, issue: issue)
        let draw = store.createOrGetDraw(category: category, issue: issue, source: source)
        if let latest = store.latestVersion(draw),
           latest.frontNumbers == result.frontNumbers, latest.backNumbers == result.backNumbers {
            return latest
        }
        return store.addVersion(to: draw, front: result.frontNumbers, back: result.backNumbers,
                                prizes: result.prizes, drawDate: result.drawDate,
                                origin: "fetched", sourceURL: result.sourceURL)
    }

    public func recordManual(category: Category, issue: String, front: [Int], back: [Int],
                             prizes: [String: Int]? = nil, drawDate: Date? = nil) -> DrawVersion {
        let draw = store.createOrGetDraw(category: category, issue: issue, source: .manual)
        if let latest = store.latestVersion(draw),
           latest.frontNumbers == front, latest.backNumbers == back, latest.prizes == prizes {
            return latest
        }
        return store.addVersion(to: draw, front: front, back: back, prizes: prizes,
                                drawDate: drawDate, origin: "manual", sourceURL: nil)
    }
}
