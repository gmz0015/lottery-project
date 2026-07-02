import SwiftUI
import LotteryKit
import UserNotifications
#if os(macOS)
import AppKit
#endif

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var modelBaseURL = ""
    @State private var modelAPIKey = ""
    @State private var modelName = ""
    @State private var wsBaseURL = ""
    @State private var wsToken = ""
    @State private var wsEnabled = false
    @State private var language: LanguagePreference = .system
    @State private var timeZoneIdentifier = ""
    @State private var notificationsEnabled = false
    @State private var appearance: AppearancePreference = .system
    @State private var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var notificationMessage = ""
    @State private var isRequestingNotificationAuthorization = false
    @State private var saved = false

    var body: some View {
        PageScroll {
            GlassPanel {
                Label("视觉模型（OpenAI 兼容）", systemImage: "camera.metering.matrix")
                    .font(.headline)
                settingsField("Base URL", placeholder: "https://api.openai.com/v1", text: $modelBaseURL)
                SecureField("API Key", text: $modelAPIKey)
                    .textFieldStyle(.roundedBorder)
                settingsField("模型名", placeholder: "gpt-4o", text: $modelName)
            }

            GlassPanel {
                Label("Web 服务数据源", systemImage: "server.rack")
                    .font(.headline)
                Toggle("启用 Web 服务数据源", isOn: $wsEnabled)
                    .accessibilityIdentifier("webServiceEnabledToggle")
                settingsField("Base URL", placeholder: "http://host:8080", text: $wsBaseURL)
                SecureField("共享 Token", text: $wsToken)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!wsEnabled)
                if !wsEnabled {
                    Text("Web 服务数据源未启用")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            GlassPanel {
                Label("系统偏好", systemImage: "switch.2")
                    .font(.headline)

                Picker("语言", selection: $language) {
                    ForEach(LanguagePreference.allCases, id: \.self) { language in
                        Text(language.title).tag(language)
                    }
                }
                .pickerStyle(.menu)

                Picker("时区", selection: $timeZoneIdentifier) {
                    ForEach(TimeZoneChoice.common) { choice in
                        Text(choice.title).tag(choice.identifier)
                    }
                }
                .pickerStyle(.menu)

                Picker("页面风格", selection: $appearance) {
                    ForEach(AppearancePreference.allCases, id: \.self) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)

                Divider()

                Toggle("发送通知", isOn: $notificationsEnabled)

                HStack(spacing: 10) {
                    Label(notificationAuthorizationText, systemImage: notificationAuthorizationIcon)
                        .font(.callout)
                        .foregroundStyle(notificationAuthorizationColor)

                    Spacer(minLength: 12)

                    Button {
                        refreshNotificationAuthorizationStatus()
                    } label: {
                        Label("检查权限", systemImage: "checklist")
                    }
                    .interactiveControl()

                    Button {
                        requestNotificationAuthorization()
                    } label: {
                        Label("授权通知", systemImage: "bell.badge")
                    }
                    .disabled(isRequestingNotificationAuthorization || notificationAuthorizationStatus == .authorized)
                    .interactiveControl()

                    if notificationAuthorizationStatus == .denied {
                        Button {
                            openNotificationSettings()
                        } label: {
                            Label("打开系统设置", systemImage: "gearshape")
                        }
                        .interactiveControl()
                    }
                }

                if !notificationMessage.isEmpty {
                    Text(notificationMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button {
                    save()
                } label: {
                    Label("保存", systemImage: "checkmark")
                }
                .buttonStyle(.glassProminent)
                .interactiveControl()

                StatusBanner(text: saved ? "已保存" : "")
            }
        }
        .navigationTitle("设置")
        .animation(AppMotion.reveal, value: saved)
        .animation(AppMotion.reveal, value: wsEnabled)
        .animation(AppMotion.reveal, value: notificationAuthorizationStatus)
        .onAppear {
            load()
            refreshNotificationAuthorizationStatus()
        }
        .onChange(of: modelBaseURL) { _, _ in saved = false }
        .onChange(of: modelAPIKey) { _, _ in saved = false }
        .onChange(of: modelName) { _, _ in saved = false }
        .onChange(of: wsBaseURL) { _, _ in saved = false }
        .onChange(of: wsToken) { _, _ in saved = false }
        .onChange(of: wsEnabled) { _, _ in saved = false }
        .onChange(of: language) { _, _ in saved = false }
        .onChange(of: timeZoneIdentifier) { _, _ in saved = false }
        .onChange(of: notificationsEnabled) { _, _ in saved = false }
        .onChange(of: appearance) { _, _ in saved = false }
    }

    private func settingsField(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func load() {
        let s = model.settings
        modelBaseURL = s.modelBaseURL; modelAPIKey = s.modelAPIKey; modelName = s.modelName
        wsBaseURL = s.webServiceBaseURL; wsToken = s.webServiceToken; wsEnabled = s.webServiceEnabled
        language = s.language
        timeZoneIdentifier = s.timeZoneIdentifier
        notificationsEnabled = s.notificationsEnabled
        appearance = s.appearance
    }

    private func save() {
        let s = model.settings
        s.modelBaseURL = modelBaseURL; s.modelAPIKey = modelAPIKey; s.modelName = modelName
        s.webServiceBaseURL = wsBaseURL; s.webServiceToken = wsToken; s.webServiceEnabled = wsEnabled
        s.language = language
        s.timeZoneIdentifier = timeZoneIdentifier
        s.notificationsEnabled = notificationsEnabled
        s.appearance = appearance
        model.rebuildServices()
        if notificationsEnabled, notificationAuthorizationStatus != .authorized {
            requestNotificationAuthorization()
        }
        withAnimation(AppMotion.reveal) {
            saved = true
        }
    }

    private var notificationAuthorizationText: String {
        switch notificationAuthorizationStatus {
        case .notDetermined: "通知权限未授权"
        case .denied: "通知权限已拒绝"
        case .authorized: "通知权限已开启"
        case .provisional: "通知权限为临时授权"
        case .ephemeral: "通知权限为临时会话授权"
        @unknown default: "通知权限状态未知"
        }
    }

    private var notificationAuthorizationIcon: String {
        switch notificationAuthorizationStatus {
        case .authorized, .provisional, .ephemeral: "bell.fill"
        case .denied: "bell.slash.fill"
        default: "bell"
        }
    }

    private var notificationAuthorizationColor: Color {
        switch notificationAuthorizationStatus {
        case .authorized, .provisional, .ephemeral: .green
        case .denied: .red
        default: .secondary
        }
    }

    private func refreshNotificationAuthorizationStatus() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run {
                notificationAuthorizationStatus = settings.authorizationStatus
                notificationMessage = message(for: settings.authorizationStatus)
            }
        }
    }

    private func requestNotificationAuthorization() {
        isRequestingNotificationAuthorization = true
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                let settings = await UNUserNotificationCenter.current().notificationSettings()
                await MainActor.run {
                    notificationAuthorizationStatus = settings.authorizationStatus
                    notificationsEnabled = granted
                    model.settings.notificationsEnabled = granted
                    notificationMessage = granted ? "已获得通知权限" : message(for: settings.authorizationStatus)
                    isRequestingNotificationAuthorization = false
                }
            } catch {
                await MainActor.run {
                    notificationMessage = "通知授权失败：\(error.localizedDescription)"
                    isRequestingNotificationAuthorization = false
                }
            }
        }
    }

    private func message(for status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "开启通知后可请求系统授权。"
        case .denied: "通知已被系统拒绝，请前往系统设置为彩票验奖开启通知。"
        case .authorized: "系统允许本应用发送通知。"
        case .provisional: "系统允许本应用临时发送通知。"
        case .ephemeral: "系统允许本应用在当前会话发送通知。"
        @unknown default: "无法识别当前通知权限状态。"
        }
    }

    private func openNotificationSettings() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }
}
