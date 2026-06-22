import SwiftUI
import AppKit
import LotteryKit

struct TicketDetailView: View {
    @EnvironmentObject var model: AppModel
    let ticket: Ticket
    @State private var refreshToken = 0
    @State private var sheetDraw: Draw?
    @State private var status = ""
    private let imageStore = ImageStore()

    private var category: Category { Category(rawValue: ticket.category) ?? .ssq }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let name = ticket.imageFileName, let data = imageStore.load(name), let img = NSImage(data: data) {
                    Image(nsImage: img).resizable().scaledToFit().frame(maxHeight: 200)
                }
                ForEach(Array(ticket.bets.enumerated()), id: \.offset) { _, bet in
                    HStack { NumberBadges(numbers: bet.front, color: .red); NumberBadges(numbers: bet.back, color: .blue) }
                }
                Divider()
                HStack {
                    Text("再次验奖：").bold()
                    ForEach(model.availableSources(for: category), id: \.self) { src in
                        Button(src.displayName) { Task { await reverify(source: src, force: false) } }
                    }
                }
                if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.secondary) }
                Divider()
                Text("验奖记录").font(.headline)
                ForEach(ticket.verifications.sorted(by: { $0.createdAt > $1.createdAt }), id: \.id) { rec in
                    verificationRow(rec)
                }
            }
            .padding()
            .id(refreshToken)
        }
        .navigationTitle("第 \(ticket.issue) 期")
        .sheet(item: $sheetDraw) { draw in
            DrawVersionSheet(draw: draw, ticket: ticket) { refreshToken += 1 }
                .environmentObject(model)
        }
    }

    @ViewBuilder private func verificationRow(_ rec: VerificationRecord) -> some View {
        let srcName = rec.drawVersion?.draw.map { DataSourceKind(rawValue: $0.source)?.displayName ?? $0.source } ?? "—"
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(srcName).font(.caption).padding(4).background(.quaternary).clipShape(Capsule())
                Text("v\(rec.drawVersion?.versionNumber ?? 0)").font(.caption)
                Spacer()
                Text(rec.totalAmount > 0 ? "¥\(rec.totalAmount)" : (rec.results.contains { $0.result.isWin } ? "中奖(金额以官方为准)" : "未中奖"))
                    .foregroundStyle(rec.results.contains { $0.result.isWin } ? .green : .secondary)
            }
            ForEach(Array(rec.results.enumerated()), id: \.offset) { _, snap in
                Text(snap.result.tierName.map { "\($0)" } ?? "未中奖").font(.caption2)
            }
            if let draw = rec.drawVersion?.draw {
                Button("查看/管理该期开奖版本") { sheetDraw = draw }.font(.caption)
            }
        }
        .padding(8).background(.background.secondary).clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func reverify(source: DataSourceKind, force: Bool) async {
        status = "验奖中…"
        do {
            let version = try await model.fetchService.fetch(category: category, issue: ticket.issue,
                                                             source: source, forceRefresh: force)
            var total = 0; var snaps: [BetResultSnapshot] = []
            for bet in ticket.bets {
                let r = PrizeEvaluator.evaluate(category: category, bet: bet,
                                                drawFront: version.frontNumbers, drawBack: version.backNumbers,
                                                prizes: version.prizes)
                total += r.amount ?? 0
                snaps.append(BetResultSnapshot(bet: bet, result: r))
            }
            _ = model.store.addVerification(ticket: ticket, drawVersion: version, results: snaps, totalAmount: total)
            refreshToken += 1
            status = "已追加验奖记录（\(source.displayName)）"
        } catch DrawSourceError.notFound {
            status = "该期未开奖或不存在"
        } catch {
            status = "错误：\(error.localizedDescription)"
        }
    }
}
