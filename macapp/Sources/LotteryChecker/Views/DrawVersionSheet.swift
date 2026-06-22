import SwiftUI
import AppKit
import LotteryKit

struct DrawVersionSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let draw: Draw
    let ticket: Ticket
    var onChange: () -> Void

    @State private var frontText = ""
    @State private var backText = ""
    @State private var status = ""

    private var category: Category { Category(rawValue: draw.category) ?? .ssq }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("开奖版本 · \(category.displayName) 第 \(draw.issue) 期 · \(DataSourceKind(rawValue: draw.source)?.displayName ?? draw.source)")
                .font(.headline)
            List(draw.versions.sorted(by: { $0.versionNumber > $1.versionNumber }), id: \.id) { v in
                VStack(alignment: .leading) {
                    HStack {
                        Text("v\(v.versionNumber)").bold()
                        Text(v.origin == "fetched" ? "抓取" : "手动").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("用此版本重验") { Task { await reverify(with: v) } }.font(.caption)
                    }
                    HStack { NumberBadges(numbers: v.frontNumbers, color: .red); NumberBadges(numbers: v.backNumbers, color: .blue) }
                    if let urlStr = v.sourceURL, let url = URL(string: urlStr) {
                        Link("来源页", destination: url).font(.caption)
                    }
                }
            }
            .frame(minHeight: 180)
            Divider()
            Text("手动新增/修改版本").font(.subheadline)
            TextField("前区/红球（空格分隔）", text: $frontText)
            TextField("后区/蓝球（空格分隔）", text: $backText)
            if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.red) }
            HStack {
                Button("保存为新版本") { addManualVersion() }
                Spacer()
                Button("关闭") { dismiss() }
            }
        }
        .padding()
        .frame(width: 460)
    }

    private func parseNums(_ s: String) -> [Int] {
        s.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Int($0) }
    }

    private func addManualVersion() {
        let front = parseNums(frontText), back = parseNums(backText)
        if let err = NumberValidation.validate(category: category, front: front, back: back) {
            status = err; return
        }
        _ = model.store.addVersion(to: draw, front: front, back: back, prizes: nil,
                                   drawDate: nil, origin: "manual", sourceURL: nil)
        frontText = ""; backText = ""; status = ""
        onChange()
    }

    private func reverify(with v: DrawVersion) async {
        var total = 0; var snaps: [BetResultSnapshot] = []
        for bet in ticket.bets {
            let r = PrizeEvaluator.evaluate(category: category, bet: bet,
                                            drawFront: v.frontNumbers, drawBack: v.backNumbers, prizes: v.prizes)
            total += r.amount ?? 0
            snaps.append(BetResultSnapshot(bet: bet, result: r))
        }
        _ = model.store.addVerification(ticket: ticket, drawVersion: v, results: snaps, totalAmount: total)
        onChange()
        dismiss()
    }
}
