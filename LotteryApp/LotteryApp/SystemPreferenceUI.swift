import SwiftUI
import LotteryKit

extension LanguagePreference {
    var title: String {
        switch self {
        case .system: "跟随系统"
        case .simplifiedChinese: "简体中文"
        case .english: "English"
        }
    }

    var locale: Locale {
        switch self {
        case .system: .autoupdatingCurrent
        case .simplifiedChinese: Locale(identifier: rawValue)
        case .english: Locale(identifier: rawValue)
        }
    }
}

extension AppearancePreference {
    var title: String {
        switch self {
        case .system: "跟随系统"
        case .light: "白色"
        case .dark: "黑色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct TimeZoneChoice: Identifiable {
    let title: String
    let identifier: String

    var id: String { identifier }

    static let common: [TimeZoneChoice] = [
        TimeZoneChoice(title: "跟随系统", identifier: ""),
        TimeZoneChoice(title: "中国标准时间", identifier: "Asia/Shanghai"),
        TimeZoneChoice(title: "协调世界时", identifier: "UTC"),
        TimeZoneChoice(title: "美国太平洋时间", identifier: "America/Los_Angeles"),
        TimeZoneChoice(title: "美国东部时间", identifier: "America/New_York"),
        TimeZoneChoice(title: "英国时间", identifier: "Europe/London"),
    ]
}
