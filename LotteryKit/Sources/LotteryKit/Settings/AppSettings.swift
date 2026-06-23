import Foundation

public final class AppSettings {
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    private func str(_ key: String) -> String { defaults.string(forKey: key) ?? "" }

    public var modelBaseURL: String {
        get { str("modelBaseURL") } set { defaults.set(newValue, forKey: "modelBaseURL") }
    }
    public var modelAPIKey: String {
        get { str("modelAPIKey") } set { defaults.set(newValue, forKey: "modelAPIKey") }
    }
    public var modelName: String {
        get { str("modelName") } set { defaults.set(newValue, forKey: "modelName") }
    }
    public var webServiceBaseURL: String {
        get { str("webServiceBaseURL") } set { defaults.set(newValue, forKey: "webServiceBaseURL") }
    }
    public var webServiceToken: String {
        get { str("webServiceToken") } set { defaults.set(newValue, forKey: "webServiceToken") }
    }
    public var webServiceEnabled: Bool {
        get { defaults.bool(forKey: "webServiceEnabled") } set { defaults.set(newValue, forKey: "webServiceEnabled") }
    }
    public var sourcePriority: [DataSourceKind] {
        get {
            guard let arr = defaults.array(forKey: "sourcePriority") as? [String] else {
                return [.officialSporttery, .officialCWL, .webService, .manual]
            }
            return arr.compactMap { DataSourceKind(rawValue: $0) }
        }
        set { defaults.set(newValue.map(\.rawValue), forKey: "sourcePriority") }
    }
}
