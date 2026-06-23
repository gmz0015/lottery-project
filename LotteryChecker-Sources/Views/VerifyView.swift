import SwiftUI
import AppKit
import LotteryKit

struct VerifyView: View {
    @EnvironmentObject var model: AppModel
    @State private var imageData: Data?
    @State private var category: Category = .ssq
    @State private var issue = ""
    @State private var frontText = ""
    @State private var backText = ""
    @State private var selectedSource: DataSourceKind = .officialCWL
    @State private var status = ""
    @State private var busy = false

    private let imageStore = ImageStore()

    var body: some View {
        Form {
            Section("彩票图片") {
                if let imageData, let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage).resizable().scaledToFit().frame(maxHeight: 180)
                }
                Button("选择图片…") { pickImage() }
                Button("识别") { Task { await recognize() } }
                    .disabled(imageData == nil || busy)
            }
            Section("确认（可编辑）") {
                Picker("彩种", selection: $category) {
                    ForEach(Category.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                TextField("期数", text: $issue)
                TextField("前区/红球（空格分隔）", text: $frontText)
                TextField("后区/蓝球（空格分隔）", text: $backText)
                Picker("数据源", selection: $selectedSource) {
                    ForEach(model.availableSources(for: category), id: \.self) { Text($0.displayName).tag($0) }
                }
                Button("复式/胆拖（开发中）") {}.disabled(true)
            }
            if !status.isEmpty {
                Text(status).foregroundStyle(status.hasPrefix("错误") ? .red : .secondary)
            }
            Button("验奖") { Task { await verify() } }
                .disabled(busy)
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("验奖")
        .onChange(of: category) { _, newValue in
            selectedSource = model.availableSources(for: newValue).first ?? .manual
        }
    }

    private func parseNums(_ s: String) -> [Int] {
        s.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Int($0) }
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            imageData = try? Data(contentsOf: url)
            status = ""
        }
    }

    private func recognize() async {
        guard let imageData else { return }
        busy = true; status = "识别中…"
        defer { busy = false }
        do {
            let t = try await model.recognizer.recognize(imageData: imageData)
            category = t.category
            issue = t.issue
            frontText = (t.bets.first?.front ?? []).map(String.init).joined(separator: " ")
            backText = (t.bets.first?.back ?? []).map(String.init).joined(separator: " ")
            selectedSource = model.availableSources(for: t.category).first ?? .manual
            status = "识别完成，请核对"
        } catch RecognizerError.notConfigured {
            status = "错误：请先在设置中配置模型"
        } catch {
            status = "错误：识别失败 \(error.localizedDescription)"
        }
    }

    private func verify() async {
        let front = parseNums(frontText), back = parseNums(backText)
        if let err = NumberValidation.validate(category: category, front: front, back: back) {
            status = "错误：\(err)"; return
        }
        guard !issue.isEmpty else { status = "错误：请填写期数"; return }
        busy = true; status = "验奖中…"
        defer { busy = false }
        do {
            var fileName: String?
            if let imageData { fileName = try? imageStore.save(imageData) }
            let bet = Bet(front: front, back: back)
            let ticket = model.store.saveTicket(category: category, issue: issue, bets: [bet],
                                                imageFileName: fileName, cost: 2, purchaseDate: Date())
            let version = try await model.fetchService.fetch(category: category, issue: issue,
                                                             source: selectedSource, forceRefresh: false)
            let r = PrizeEvaluator.evaluate(category: category, bet: bet,
                                            drawFront: version.frontNumbers, drawBack: version.backNumbers,
                                            prizes: version.prizes)
            let snap = BetResultSnapshot(bet: bet, result: r)
            _ = model.store.addVerification(ticket: ticket, drawVersion: version,
                                            results: [snap], totalAmount: r.amount ?? 0)
            status = r.isWin ? "中奖：\(r.tierName ?? "")（\(r.amount.map { "¥\($0)" } ?? "金额以官方为准")）"
                             : "未中奖"
        } catch DrawSourceError.notFound {
            status = "错误：该期未开奖或不存在"
        } catch {
            status = "错误：\(error.localizedDescription)"
        }
    }
}
