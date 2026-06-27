import SwiftUI
import LotteryKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var modelBaseURL = ""
    @State private var modelAPIKey = ""
    @State private var modelName = ""
    @State private var wsBaseURL = ""
    @State private var wsToken = ""
    @State private var wsEnabled = false
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

            HStack {
                Button {
                    save()
                } label: {
                    Label("保存", systemImage: "checkmark")
                }
                .buttonStyle(.glassProminent)

                StatusBanner(text: saved ? "已保存" : "")
            }
        }
        .navigationTitle("设置")
        .onAppear { load() }
        .onChange(of: modelBaseURL) { _, _ in saved = false }
        .onChange(of: modelAPIKey) { _, _ in saved = false }
        .onChange(of: modelName) { _, _ in saved = false }
        .onChange(of: wsBaseURL) { _, _ in saved = false }
        .onChange(of: wsToken) { _, _ in saved = false }
        .onChange(of: wsEnabled) { _, _ in saved = false }
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
    }

    private func save() {
        let s = model.settings
        s.modelBaseURL = modelBaseURL; s.modelAPIKey = modelAPIKey; s.modelName = modelName
        s.webServiceBaseURL = wsBaseURL; s.webServiceToken = wsToken; s.webServiceEnabled = wsEnabled
        model.rebuildServices()
        saved = true
    }
}
