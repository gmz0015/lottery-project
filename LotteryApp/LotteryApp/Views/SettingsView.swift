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
        Form {
            Section("视觉模型（OpenAI 兼容）") {
                TextField("Base URL（如 https://api.openai.com/v1）", text: $modelBaseURL)
                SecureField("API Key", text: $modelAPIKey)
                TextField("模型名（如 gpt-4o）", text: $modelName)
            }
            Section("Web 服务数据源") {
                Toggle("启用 Web 服务数据源", isOn: $wsEnabled)
                TextField("Base URL（如 http://host:8080）", text: $wsBaseURL)
                SecureField("共享 Token", text: $wsToken)
            }
            Button("保存") { save() }
            if saved { Text("已保存").foregroundStyle(.green) }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("设置")
        .onAppear { load() }
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
