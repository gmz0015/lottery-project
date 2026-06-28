import SwiftUI
import LotteryKit

struct DrawEntrySheet: View {
    enum Mode: String, Identifiable {
        case manual
        case fetch

        var id: String { rawValue }
    }

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let initialMode: Mode
    var onChange: () -> Void

    @State private var mode: Mode
    @State private var category: Category = .ssq
    @State private var issue = ""
    @State private var frontText = ""
    @State private var backText = ""
    @State private var firstPrizeText = ""
    @State private var secondPrizeText = ""
    @State private var drawDate = Date()
    @State private var includeDate = false
    @State private var fetchSourceChoice: FetchSourceChoice = .official
    @State private var status = ""
    @State private var isWorking = false

    init(initialMode: Mode, onChange: @escaping () -> Void) {
        self.initialMode = initialMode
        self.onChange = onChange
        _mode = State(initialValue: initialMode)
    }

    private var canSubmit: Bool {
        !isWorking && !issue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var selectedFetchSource: DataSourceKind {
        switch fetchSourceChoice {
        case .official:
            return category == .ssq ? .officialCWL : .officialSporttery
        case .webService:
            return .webService
        }
    }

    private var webServiceReady: Bool {
        model.settings.webServiceEnabled && !model.settings.webServiceBaseURL.isEmpty
    }

    var body: some View {
        GlassEffectContainer(spacing: 14) {
            VStack(alignment: .leading, spacing: 16) {
                Label(mode == .manual ? "手动录入开奖" : "拉取指定期开奖",
                      systemImage: mode == .manual ? "square.and.pencil" : "arrow.down.doc")
                    .font(.headline)

                Picker("方式", selection: $mode) {
                    Label("手动录入", systemImage: "square.and.pencil").tag(Mode.manual)
                    Label("指定期拉取", systemImage: "arrow.down.doc").tag(Mode.fetch)
                }
                .pickerStyle(.segmented)

                formBody

                StatusBanner(text: status)

                HStack {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isWorking {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label(mode == .manual ? "保存" : "获取", systemImage: mode == .manual ? "checkmark" : "arrow.down")
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .interactiveControl()
                    .disabled(!canSubmit || (mode == .fetch && fetchSourceChoice == .webService && !webServiceReady))

                    Spacer()

                    Button("关闭") { dismiss() }
                        .buttonStyle(.glass)
                        .interactiveControl()
                }
            }
            .padding()
        }
        .frame(width: 520)
        .background(.regularMaterial)
        .animation(AppMotion.reveal, value: mode)
        .animation(AppMotion.reveal, value: includeDate)
        .animation(AppMotion.reveal, value: fetchSourceChoice)
        .animation(AppMotion.reveal, value: status)
        .animation(AppMotion.reveal, value: isWorking)
        .onChange(of: category) { _, _ in status = "" }
        .onChange(of: mode) { _, _ in status = "" }
        .onAppear {
            mode = initialMode
        }
    }

    @ViewBuilder
    private var formBody: some View {
        GlassPanel(spacing: 12) {
            Picker("彩种", selection: $category) {
                ForEach(Category.allCases, id: \.self) { category in
                    Text(category.displayName).tag(category)
                }
            }
            .pickerStyle(.segmented)

            labeledField("期号", placeholder: "例如 2026070", text: $issue)

            Group {
                if mode == .manual {
                    manualFields
                } else {
                    fetchFields
                }
            }
            .softRevealTransition()
        }
    }

    @ViewBuilder
    private var manualFields: some View {
        labeledField(category == .ssq ? "红球" : "前区",
                     placeholder: "空格或逗号分隔，\(category.frontCount) 个，1-\(category.frontMax)",
                     text: $frontText)
        labeledField(category == .ssq ? "蓝球" : "后区",
                     placeholder: "空格或逗号分隔，\(category.backCount) 个，1-\(category.backMax)",
                     text: $backText)

        Toggle("填写开奖日期", isOn: $includeDate)
        if includeDate {
            DatePicker("开奖日期", selection: $drawDate, displayedComponents: .date)
                .softRevealTransition()
        }

        HStack(spacing: 12) {
            labeledField("一等奖金额", placeholder: "可选，支持元或万", text: $firstPrizeText)
            labeledField("二等奖金额", placeholder: "可选，支持元或万", text: $secondPrizeText)
        }
    }

    @ViewBuilder
    private var fetchFields: some View {
        Picker("来源", selection: $fetchSourceChoice) {
            Label("官方网站", systemImage: "building.columns").tag(FetchSourceChoice.official)
            Label("Web 服务", systemImage: "server.rack").tag(FetchSourceChoice.webService)
        }
        .pickerStyle(.segmented)

        HStack {
            Label(selectedFetchSource.displayName, systemImage: fetchSourceChoice == .official ? "building.columns" : "server.rack")
            Spacer()
            if fetchSourceChoice == .webService && !webServiceReady {
                Text("未启用")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)

        if fetchSourceChoice == .webService && !webServiceReady {
            Text("请先在设置中启用 Web 服务数据源并填写 Base URL。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .softRevealTransition()
        }
    }

    private func labeledField(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func submit() async {
        withAnimation(AppMotion.reveal) {
            status = ""
            isWorking = true
        }
        defer {
            withAnimation(AppMotion.reveal) {
                isWorking = false
            }
        }

        do {
            if mode == .manual {
                try saveManualEntry()
            } else {
                try await fetchEntry()
            }
            onChange()
        } catch DrawSourceError.notFound {
            status = "错误：该期未开奖或不存在"
        } catch DrawSourceError.badResponse(let message) {
            status = "错误：\(message)"
        } catch {
            status = "错误：\(error.localizedDescription)"
        }
    }

    private func saveManualEntry() throws {
        let service = DrawEntryService(store: model.store)
        _ = try service.saveManualEntry(category: category,
                                        issue: issue,
                                        frontText: frontText,
                                        backText: backText,
                                        drawDate: includeDate ? drawDate : nil,
                                        prizes: try prizeAmounts())
        frontText = ""
        backText = ""
        firstPrizeText = ""
        secondPrizeText = ""
        status = "已保存 \(category.displayName) 第 \(issue.trimmingCharacters(in: .whitespacesAndNewlines)) 期"
    }

    private func fetchEntry() async throws {
        let source = selectedFetchSource
        let normalizedIssue = issue.trimmingCharacters(in: .whitespacesAndNewlines)
        status = "正在从\(source.displayName)获取第 \(normalizedIssue) 期"
        _ = try await model.fetchService.fetch(category: category,
                                               issue: normalizedIssue,
                                               source: source,
                                               forceRefresh: true)
        status = "已获取 \(category.displayName) 第 \(normalizedIssue) 期"
    }

    private func prizeAmounts() throws -> [String: Int]? {
        var prizes: [String: Int] = [:]
        let firstText = firstPrizeText.trimmingCharacters(in: .whitespacesAndNewlines)
        let secondText = secondPrizeText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !firstText.isEmpty {
            prizes["一等奖"] = try PrizeAmountParser.parse(firstText)
        }
        if !secondText.isEmpty {
            prizes["二等奖"] = try PrizeAmountParser.parse(secondText)
        }
        return prizes.isEmpty ? nil : prizes
    }
}

private enum FetchSourceChoice: String, Hashable {
    case official
    case webService
}
