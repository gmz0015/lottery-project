import SwiftUI
import AppKit
import UniformTypeIdentifiers
import LotteryKit

struct VerifyView: View {
    @Environment(AppModel.self) private var model
    @State private var imageData: Data?
    @State private var category: Category = .ssq
    @State private var issue = ""
    @State private var frontText = ""
    @State private var backText = ""
    @State private var selectedSource: DataSourceKind = .officialCWL
    @State private var status = ""
    @State private var busy = false

    private let imageStore = ImageStore()

    private var canRecognize: Bool {
        imageData != nil && !busy
    }

    private var canVerify: Bool {
        !busy
        && !issue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !frontText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !backText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        PageScroll {
            Text("验奖")
                .font(.largeTitle.weight(.semibold))

            GlassPanel {
                HStack {
                    Label("彩票图片", systemImage: "photo")
                        .font(.headline)
                    Spacer()
                    Button {
                        pickImage()
                    } label: {
                        Label("选择图片", systemImage: "photo.badge.plus")
                    }
                    .buttonStyle(.glass)
                    .accessibilityIdentifier("chooseImageButton")

                    Button {
                        Task { await recognize() }
                    } label: {
                        Label("识别", systemImage: "viewfinder")
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(!canRecognize)
                    .accessibilityIdentifier("recognizeTicketButton")
                }

                if let imageData, let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Text("未选择图片，也可以直接在下方手动输入号码。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            GlassPanel {
                Label("确认号码", systemImage: "checklist")
                    .font(.headline)

                Picker("彩种", selection: $category) {
                    ForEach(Category.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                TextField("期数", text: $issue)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("issueField")
                TextField("前区/红球（空格分隔）", text: $frontText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("frontNumbersField")
                TextField("后区/蓝球（空格分隔）", text: $backText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("backNumbersField")
                Picker("数据源", selection: $selectedSource) {
                    ForEach(model.availableSources(for: category), id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.menu)

                HStack {
                    Label("单式票", systemImage: "1.circle")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        Task { await verify() }
                    } label: {
                        Label("验奖", systemImage: "checkmark.seal")
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(!canVerify)
                    .accessibilityIdentifier("verifyTicketButton")
                }
            }

            if busy {
                ProgressView()
            }

            StatusBanner(text: status)
        }
        .navigationTitle("验奖")
        .onAppear { ensureSelectedSource() }
        .onChange(of: category) { _, newValue in
            selectedSource = model.availableSources(for: newValue).first ?? .manual
        }
    }

    private func parseNums(_ s: String) -> [Int] {
        s.split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == "，" }).compactMap { Int($0) }
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
        let trimmedIssue = issue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIssue.isEmpty else { status = "错误：请填写期数"; return }
        busy = true; status = "验奖中…"
        defer { busy = false }
        do {
            var fileName: String?
            if let imageData { fileName = try? imageStore.save(imageData) }
            let bet = Bet(front: front, back: back)
            let ticket = model.store.saveTicket(category: category, issue: trimmedIssue, bets: [bet],
                                                imageFileName: fileName, cost: 2, purchaseDate: Date())
            let version = try await model.fetchService.fetch(category: category, issue: trimmedIssue,
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

    private func ensureSelectedSource() {
        let available = model.availableSources(for: category)
        if !available.contains(selectedSource) {
            selectedSource = available.first ?? .manual
        }
    }
}
