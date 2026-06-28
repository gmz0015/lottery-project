import SwiftUI
import AppKit
import LotteryKit

struct DrawVersionSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let draw: Draw
    let ticket: Ticket
    var onChange: () -> Void

    @State private var frontText = ""
    @State private var backText = ""
    @State private var status = ""

    private var category: Category { Category(rawValue: draw.category) ?? .ssq }

    private var canSave: Bool {
        !frontText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !backText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        GlassEffectContainer(spacing: 14) {
            VStack(alignment: .leading, spacing: 14) {
                Label("\(category.displayName) 第 \(draw.issue) 期", systemImage: category.symbolName)
                    .font(.headline)
                Text(DataSourceKind(rawValue: draw.source)?.displayName ?? draw.source)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                List(draw.versions.sorted(by: { $0.versionNumber > $1.versionNumber }), id: \.id) { v in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("v\(v.versionNumber)").bold()
                            Text(v.origin == "fetched" ? "抓取" : "手动")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                Task { await reverify(with: v) }
                            } label: {
                                Label("重验", systemImage: "checkmark.seal")
                            }
                            .buttonStyle(.glass)
                            .controlSize(.small)
                        }
                        HStack {
                            NumberBadges(numbers: v.frontNumbers, color: .red)
                            NumberBadges(numbers: v.backNumbers, color: .blue)
                        }
                        if let urlStr = v.sourceURL, let url = URL(string: urlStr) {
                            Link(destination: url) {
                                Label("来源页", systemImage: "link")
                            }
                            .font(.caption)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .frame(minHeight: 220)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                GlassPanel {
                    Text("手动新增/修改版本")
                        .font(.subheadline.weight(.semibold))
                    TextField("前区/红球（空格分隔）", text: $frontText)
                        .textFieldStyle(.roundedBorder)
                    TextField("后区/蓝球（空格分隔）", text: $backText)
                        .textFieldStyle(.roundedBorder)
                    StatusBanner(text: status)
                    HStack {
                        Button {
                            addManualVersion()
                        } label: {
                            Label("保存为新版本", systemImage: "plus")
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(!canSave)

                        Spacer()

                        Button("关闭") { dismiss() }
                            .buttonStyle(.glass)
                    }
                }
            }
            .padding()
        }
        .frame(width: 520, height: 560)
        .background(.regularMaterial)
    }

    private func parseNums(_ s: String) -> [Int] {
        s.split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == "，" }).compactMap { Int($0) }
    }

    private func addManualVersion() {
        let front = parseNums(frontText), back = parseNums(backText)
        if let err = NumberValidation.validate(category: category, front: front, back: back) {
            status = err; return
        }
        let version: DrawVersion
        if DataSourceKind(rawValue: draw.source) == .manual {
            version = model.fetchService.recordManual(category: category, issue: draw.issue,
                                                      front: front, back: back, prizes: nil)
        } else {
            version = model.store.addVersion(to: draw, front: front, back: back, prizes: nil,
                                             drawDate: nil, origin: "manual", sourceURL: nil)
        }
        addVerification(with: version)
        frontText = ""; backText = ""; status = "已保存新版本并追加验奖记录"
        onChange()
    }

    private func reverify(with v: DrawVersion) async {
        addVerification(with: v)
        onChange()
        dismiss()
    }

    private func addVerification(with v: DrawVersion) {
        let evaluation = PrizeEvaluator.evaluateTicket(category: category,
                                                       bets: ticket.bets,
                                                       drawFront: v.frontNumbers,
                                                       drawBack: v.backNumbers,
                                                       prizes: v.prizes)
        _ = model.store.addVerification(ticket: ticket, drawVersion: v,
                                        results: evaluation.results, totalAmount: evaluation.totalAmount)
    }
}
