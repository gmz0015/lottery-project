import SwiftUI
import AppKit
import UniformTypeIdentifiers
import LotteryKit

struct VerifyView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppOverlayCenter.self) private var overlayCenter
    @State private var imageData: Data?
    @State private var category: Category = .ssq
    @State private var issue = ""
    @State private var editableBets = [EditableBet(category: .ssq)]
    @State private var manualDrawFrontText = ""
    @State private var manualDrawBackText = ""
    @State private var selectedSource: DataSourceKind = .officialCWL
    @State private var busy = false

    private let imageStore = ImageStore()

    private var canRecognize: Bool {
        imageData != nil && !busy
    }

    private var canVerify: Bool {
        !busy
        && !issue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !((try? validatedBets()).isNilOrEmpty)
        && (selectedSource != .manual
            || (!manualDrawFrontText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !manualDrawBackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
    }

    var body: some View {
        PageScroll {
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
                    .interactiveControl()
                    .accessibilityIdentifier("chooseImageButton")

                    Button {
                        Task { await recognize() }
                    } label: {
                        Label("识别", systemImage: "viewfinder")
                    }
                    .buttonStyle(.glassProminent)
                    .interactiveControl()
                    .disabled(!canRecognize)
                    .accessibilityIdentifier("recognizeTicketButton")
                }

                if let imageData, let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .softRevealTransition()
                } else {
                    Text("未选择图片，也可以直接在下方手动输入号码。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .softRevealTransition()
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

                BetEditor(category: category,
                          bets: $editableBets,
                          addBet: addBet,
                          removeBet: removeBet)

                Picker("数据源", selection: $selectedSource) {
                    ForEach(model.availableSources(for: category), id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.menu)

                Group {
                    if selectedSource == .manual {
                        Divider()
                        Label("手动录入开奖号", systemImage: "number.square")
                            .font(.subheadline.weight(.semibold))
                        TextField("开奖号前区/红球（空格分隔）", text: $manualDrawFrontText)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("manualDrawFrontField")
                        TextField("开奖号后区/蓝球（空格分隔）", text: $manualDrawBackText)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("manualDrawBackField")
                    }
                }
                .softRevealTransition()

                HStack {
                    Label("单式/复式", systemImage: "square.stack.3d.up")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        Task { await verify() }
                    } label: {
                        Label("验奖", systemImage: "checkmark.seal")
                    }
                    .buttonStyle(.glassProminent)
                    .interactiveControl()
                    .disabled(!canVerify)
                    .accessibilityIdentifier("verifyTicketButton")
                }
            }

        }
        .navigationTitle("验奖")
        .animation(AppMotion.reveal, value: imageData != nil)
        .animation(AppMotion.reveal, value: selectedSource)
        .animation(AppMotion.reveal, value: busy)
        .animation(AppMotion.reveal, value: editableBets.count)
        .onAppear { ensureSelectedSource() }
        .onChange(of: category) { _, newValue in
            normalizeBets(for: newValue)
            selectedSource = model.availableSources(for: newValue).first ?? .manual
        }
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            withAnimation(AppMotion.reveal) {
                imageData = try? Data(contentsOf: url)
                overlayCenter.clearToast()
            }
        }
    }

    private func recognize() async {
        guard let imageData else { return }
        busy = true
        overlayCenter.showLoading("识别中…")
        defer {
            busy = false
            overlayCenter.hideLoading()
        }
        do {
            let t = try await model.recognizer.recognize(imageData: imageData)
            category = t.category
            issue = t.issue
            editableBets = t.bets.isEmpty
                ? [EditableBet(category: t.category)]
                : t.bets.map { EditableBet(bet: $0, category: t.category) }
            selectedSource = model.availableSources(for: t.category).first ?? .manual
            overlayCenter.showToast("识别完成，请核对", style: .success)
        } catch RecognizerError.notConfigured {
            overlayCenter.showToast("错误：请先在设置中配置模型", style: .error)
        } catch {
            overlayCenter.showToast("错误：识别失败 \(error.localizedDescription)", style: .error)
        }
    }

    private func verify() async {
        let bets: [Bet]
        do {
            bets = try validatedBets()
        } catch {
            overlayCenter.showToast("错误：\(error.localizedDescription)", style: .error)
            return
        }
        let trimmedIssue = issue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIssue.isEmpty else {
            overlayCenter.showToast("错误：请填写期数", style: .error)
            return
        }
        if let err = manualDrawValidationError() {
            overlayCenter.showToast("错误：\(err)", style: .error)
            return
        }
        busy = true
        overlayCenter.showLoading("验奖中…")
        defer {
            busy = false
            overlayCenter.hideLoading()
        }
        do {
            var fileName: String?
            if let imageData { fileName = try? imageStore.save(imageData) }
            let unitCount = bets.reduce(0) { $0 + $1.singleBetCount(category: category) }
            let ticket = model.store.saveTicket(category: category, issue: trimmedIssue, bets: bets,
                                                imageFileName: fileName, cost: Double(unitCount * 2), purchaseDate: Date())
            let version = try await drawVersion(for: trimmedIssue)
            let evaluation = PrizeEvaluator.evaluateTicket(category: category,
                                                           bets: bets,
                                                           drawFront: version.frontNumbers,
                                                           drawBack: version.backNumbers,
                                                           prizes: version.prizes)
            _ = model.store.addVerification(ticket: ticket, drawVersion: version,
                                            results: evaluation.results, totalAmount: evaluation.totalAmount)
            if evaluation.isWin {
                overlayCenter.showToast(evaluation.totalAmount > 0
                    ? "中奖：¥\(evaluation.totalAmount)（共 \(unitCount) 注）"
                    : "中奖：金额以官方为准（共 \(unitCount) 注）",
                    style: .success)
            } else {
                overlayCenter.showToast("未中奖（共 \(unitCount) 注）", style: .info)
            }
        } catch DrawSourceError.notFound {
            overlayCenter.showToast("错误：该期未开奖或不存在", style: .error)
        } catch DrawSourceError.badResponse(let message) {
            overlayCenter.showToast("错误：\(message)", style: .error)
        } catch {
            overlayCenter.showToast("错误：\(error.localizedDescription)", style: .error)
        }
    }

    private func addBet() {
        editableBets.append(EditableBet(category: category))
    }

    private func removeBet(_ id: UUID) {
        guard editableBets.count > 1 else { return }
        editableBets.removeAll { $0.id == id }
    }

    private func normalizeBets(for category: Category) {
        editableBets = editableBets.map { $0.normalized(for: category) }
        if editableBets.isEmpty {
            editableBets = [EditableBet(category: category)]
        }
    }

    private func validatedBets() throws -> [Bet] {
        try editableBets.enumerated().map { index, editable in
            let front = try parseNumbers(editable.front, groupName: "前区/红球", betIndex: index)
            let back = try parseNumbers(editable.back, groupName: "后区/蓝球", betIndex: index)
            if let message = NumberValidation.validateBet(category: category, front: front, back: back) {
                throw TicketNumberInputError.invalidBet(index: index + 1, message: message)
            }
            return Bet(front: front, back: back)
        }
    }

    private func parseNumbers(_ values: [String], groupName: String, betIndex: Int) throws -> [Int] {
        try values.enumerated().map { position, value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let number = Int(trimmed) else {
                throw TicketNumberInputError.invalidNumber(index: betIndex + 1,
                                                           group: groupName,
                                                           position: position + 1)
            }
            return number
        }
    }

    private func parseDrawNumbers(_ text: String) -> [Int] {
        text.split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == "，" }).compactMap { Int($0) }
    }

    private func drawVersion(for issue: String) async throws -> DrawVersion {
        if selectedSource != .manual {
            return try await model.fetchService.fetch(category: category, issue: issue,
                                                      source: selectedSource, forceRefresh: false)
        }

        let front = parseDrawNumbers(manualDrawFrontText)
        let back = parseDrawNumbers(manualDrawBackText)
        if let err = NumberValidation.validate(category: category, front: front, back: back) {
            throw DrawSourceError.badResponse(err)
        }
        return model.fetchService.recordManual(category: category, issue: issue,
                                               front: front, back: back, prizes: nil)
    }

    private func manualDrawValidationError() -> String? {
        guard selectedSource == .manual else { return nil }
        return NumberValidation.validate(category: category,
                                         front: parseDrawNumbers(manualDrawFrontText),
                                         back: parseDrawNumbers(manualDrawBackText))
    }

    private func ensureSelectedSource() {
        let available = model.availableSources(for: category)
        if !available.contains(selectedSource) {
            selectedSource = available.first ?? .manual
        }
    }
}

private struct EditableBet: Identifiable, Equatable {
    let id: UUID
    var front: [String]
    var back: [String]

    init(id: UUID = UUID(), category: Category) {
        self.id = id
        self.front = Array(repeating: "", count: category.frontCount)
        self.back = Array(repeating: "", count: category.backCount)
    }

    init(id: UUID = UUID(), bet: Bet, category: Category) {
        self.id = id
        self.front = EditableBet.paddedStrings(from: bet.front, minimumCount: category.frontCount)
        self.back = EditableBet.paddedStrings(from: bet.back, minimumCount: category.backCount)
    }

    func normalized(for category: Category) -> EditableBet {
        EditableBet(id: id,
                    front: Self.resized(front, count: category.frontCount),
                    back: Self.resized(back, count: category.backCount))
    }

    private init(id: UUID, front: [String], back: [String]) {
        self.id = id
        self.front = front
        self.back = back
    }

    private static func paddedStrings(from numbers: [Int], minimumCount: Int) -> [String] {
        let strings = numbers.map { String(format: "%02d", $0) }
        guard strings.count < minimumCount else { return strings }
        return strings + Array(repeating: "", count: minimumCount - strings.count)
    }

    private static func resized(_ values: [String], count: Int) -> [String] {
        if values.count == count { return values }
        if values.count > count { return Array(values.prefix(count)) }
        return values + Array(repeating: "", count: count - values.count)
    }
}

private struct BetEditor: View {
    let category: Category
    @Binding var bets: [EditableBet]
    let addBet: () -> Void
    let removeBet: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("票面号码", systemImage: category.symbolName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(action: addBet) {
                    Label("增加一注", systemImage: "plus.circle")
                }
                .buttonStyle(.glass)
                .interactiveControl()
                .accessibilityIdentifier("addBetButton")
            }

            VStack(spacing: 10) {
                ForEach(Array(bets.enumerated()), id: \.element.id) { index, bet in
                    BetRowEditor(category: category,
                                 index: index,
                                 bet: binding(for: bet.id),
                                 canRemove: bets.count > 1) {
                        removeBet(bet.id)
                    }
                }
            }
        }
    }

    private func binding(for id: UUID) -> Binding<EditableBet> {
        Binding {
            bets.first { $0.id == id } ?? EditableBet(category: category)
        } set: { newValue in
            if let index = bets.firstIndex(where: { $0.id == id }) {
                bets[index] = newValue
            }
        }
    }
}

private struct BetRowEditor: View {
    let category: Category
    let index: Int
    @Binding var bet: EditableBet
    let canRemove: Bool
    let remove: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("第 \(index + 1) 注")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)

            HStack(spacing: 10) {
                NumberGroupEditor(color: .red,
                                  values: $bet.front,
                                  maxValue: category.frontMax,
                                  accessibilityPrefix: "bet_\(index)_front")
                NumberGroupEditor(color: .blue,
                                  values: $bet.back,
                                  maxValue: category.backMax,
                                  accessibilityPrefix: "bet_\(index)_back")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: remove) {
                Image(systemName: "minus.circle")
                    .imageScale(.large)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(canRemove ? .red : .secondary)
            .disabled(!canRemove)
            .help("删除这一注")
            .accessibilityIdentifier("removeBet_\(index)")
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.primary.opacity(0.035))
        }
    }
}

private struct NumberGroupEditor: View {
    let color: Color
    @Binding var values: [String]
    let maxValue: Int
    let accessibilityPrefix: String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(values.indices, id: \.self) { index in
                NumberSlotField(value: $values[index],
                                color: color,
                                maxValue: maxValue,
                                accessibilityIdentifier: "\(accessibilityPrefix)_\(index)")
            }
        }
        .padding(8)
        .background {
            DashedRoundedRectangle(color: color)
        }
    }
}

private struct NumberSlotField: View {
    @Binding var value: String
    let color: Color
    let maxValue: Int
    let accessibilityIdentifier: String
    @State private var isPickerPresented = false

    var body: some View {
        TextField("", text: sanitizedBinding)
            .font(.system(.body, design: .rounded).weight(.semibold))
            .multilineTextAlignment(.center)
            .textFieldStyle(.plain)
            .padding(.trailing, 10)
            .frame(width: 44, height: 30)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(color.opacity(0.12))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(color.opacity(0.45), lineWidth: 1)
            }
            .overlay(alignment: .trailing) {
                Button {
                    isPickerPresented.toggle()
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(color.opacity(0.72))
                        .frame(width: 12, height: 24)
                }
                .buttonStyle(.plain)
                .help("选择号码")
                .accessibilityIdentifier("\(accessibilityIdentifier)_picker")
            }
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .onTapGesture(count: 2) {
                isPickerPresented.toggle()
            }
            .popover(isPresented: $isPickerPresented, arrowEdge: .bottom) {
                NumberPickerPopover(value: $value,
                                    isPresented: $isPickerPresented,
                                    color: color,
                                    maxValue: maxValue)
            }
            .help("直接输入号码，或点右侧小箭头选择")
            .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var sanitizedBinding: Binding<String> {
        Binding {
            value
        } set: { newValue in
            let digits = newValue.filter(\.isNumber)
            value = String(digits.prefix(2))
        }
    }
}

private struct NumberPickerPopover: View {
    @Binding var value: String
    @Binding var isPresented: Bool
    let color: Color
    let maxValue: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 38), spacing: 8)], spacing: 8) {
                    ForEach(1...maxValue, id: \.self) { number in
                        Button {
                            value = String(format: "%02d", number)
                            isPresented = false
                        } label: {
                            Text(String(format: "%02d", number))
                                .font(.system(.callout, design: .rounded).weight(.semibold))
                                .frame(width: 34, height: 28)
                        }
                        .buttonStyle(.plain)
                        .background {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(isSelected(number) ? color.opacity(0.22) : Color.primary.opacity(0.045))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(isSelected(number) ? color.opacity(0.65) : Color.clear, lineWidth: 1)
                        }
                        .id(number)
                    }
                }
                .padding(10)
            }
            .frame(width: 230, height: 180)
            .onAppear {
                if let selected = Int(value) {
                    proxy.scrollTo(selected, anchor: .center)
                }
            }
        }
    }

    private func isSelected(_ number: Int) -> Bool {
        Int(value) == number
    }
}

private struct DashedRoundedRectangle: View {
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(color.opacity(0.42),
                    style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.035))
            }
    }
}

private enum TicketNumberInputError: LocalizedError {
    case invalidNumber(index: Int, group: String, position: Int)
    case invalidBet(index: Int, message: String)

    var errorDescription: String? {
        switch self {
        case let .invalidNumber(index, group, position):
            "第 \(index) 注\(group)第 \(position) 个号码无效"
        case let .invalidBet(index, message):
            "第 \(index) 注\(message)"
        }
    }
}

private extension Optional where Wrapped == [Bet] {
    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }
}
