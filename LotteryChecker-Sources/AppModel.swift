import SwiftUI
import LotteryKit

@MainActor
final class AppModel: ObservableObject {
    let store: Store
    let settings: AppSettings
    @Published private(set) var fetchService: DrawFetchService
    @Published private(set) var recognizer: VisionRecognizer

    init() {
        // 失败则用内存库兜底，保证 app 可启动
        let s = (try? Store()) ?? (try! Store(inMemory: true))
        self.store = s
        let cfg = AppSettings()
        self.settings = cfg
        self.fetchService = AppModel.makeFetch(store: s, settings: cfg)
        self.recognizer = AppModel.makeRecognizer(settings: cfg)
    }

    static func makeFetch(store: Store, settings: AppSettings) -> DrawFetchService {
        var sources: [DataSourceKind: DrawDataSource] = [
            .officialSporttery: SportteryDataSource(),
            .officialCWL: CWLDataSource(),
        ]
        if settings.webServiceEnabled, !settings.webServiceBaseURL.isEmpty {
            sources[.webService] = WebServiceDataSource(baseURL: settings.webServiceBaseURL, token: settings.webServiceToken)
        }
        return DrawFetchService(store: store, sources: sources)
    }

    static func makeRecognizer(settings: AppSettings) -> VisionRecognizer {
        OpenAIVisionRecognizer(baseURL: settings.modelBaseURL, apiKey: settings.modelAPIKey, model: settings.modelName)
    }

    func rebuildServices() {
        fetchService = AppModel.makeFetch(store: store, settings: settings)
        recognizer = AppModel.makeRecognizer(settings: settings)
    }

    /// 当前可用于验奖的数据源（含手动）。
    func availableSources(for category: Category) -> [DataSourceKind] {
        settings.sourcePriority.filter { kind in
            switch kind {
            case .officialSporttery: return category == .dlt
            case .officialCWL: return category == .ssq
            case .webService: return settings.webServiceEnabled && !settings.webServiceBaseURL.isEmpty
            case .manual: return true
            }
        }
    }
}
