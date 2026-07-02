import Foundation

public enum LanguagePreference: String, CaseIterable, Equatable {
    case system
    case simplifiedChinese = "zh-Hans"
    case english = "en"
}

public enum AppearancePreference: String, CaseIterable, Equatable {
    case system
    case light
    case dark
}

public final class AppSettings {
    public enum Keys {
        public static let language = "language"
        public static let timeZoneIdentifier = "timeZoneIdentifier"
        public static let notificationsEnabled = "notificationsEnabled"
        public static let appearance = "appearance"
    }

    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    private func str(_ key: String) -> String { defaults.string(forKey: key) ?? "" }
    private func value<T: RawRepresentable>(_ key: String, default defaultValue: T) -> T where T.RawValue == String {
        guard let raw = defaults.string(forKey: key), let value = T(rawValue: raw) else {
            return defaultValue
        }
        return value
    }

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
    public var language: LanguagePreference {
        get { value(Keys.language, default: .system) }
        set { defaults.set(newValue.rawValue, forKey: Keys.language) }
    }
    public var timeZoneIdentifier: String {
        get { str(Keys.timeZoneIdentifier) }
        set { defaults.set(newValue, forKey: Keys.timeZoneIdentifier) }
    }
    public var notificationsEnabled: Bool {
        get { defaults.bool(forKey: Keys.notificationsEnabled) }
        set { defaults.set(newValue, forKey: Keys.notificationsEnabled) }
    }
    public var appearance: AppearancePreference {
        get { value(Keys.appearance, default: .system) }
        set { defaults.set(newValue.rawValue, forKey: Keys.appearance) }
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
