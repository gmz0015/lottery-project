import SwiftUI
import AppKit
import LotteryKit

struct TicketDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppOverlayCenter.self) private var overlayCenter
    let ticket: Ticket
    @State private var refreshToken = 0
    @State private var sheetDraw: Draw?
    @State private var busy = false
    private let imageStore = ImageStore()

    private var category: Category { Category(rawValue: ticket.category) ?? .ssq }

    var body: some View {
        PageScroll {
            GlassPanel {
                HStack {
                    Label("票面号码", systemImage: category.symbolName)
                        .font(.headline)
                    Spacer()
                    Text(category.displayName)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(ticket.bets.enumerated()), id: \.offset) { index, bet in
                        TicketBetNumberRow(index: index, bet: bet, showsIndex: ticket.bets.count > 1)
                    }
                }
            }

            TicketInfoCard(ticket: ticket, image: ticketImage)

            GlassPanel {
                HStack {
                    Label("再次验奖", systemImage: "arrow.clockwise")
                        .font(.headline)
                    Spacer()
                    ForEach(model.availableSources(for: category), id: \.self) { src in
                        Button(src.displayName) {
                            if src == .manual {
                                sheetDraw = model.store.createOrGetDraw(category: category, issue: ticket.issue, source: .manual)
                            } else {
                                Task { await reverify(source: src, force: false) }
                            }
                        }
                        .buttonStyle(.glass)
                        .interactiveControl()
                        .disabled(busy)
                    }
                }

            }

            GlassPanel {
                Label("验奖记录", systemImage: "checklist")
                    .font(.headline)

                if ticket.verifications.isEmpty {
                    Text("暂无验奖记录")
                        .foregroundStyle(.secondary)
                }

                ForEach(ticket.verifications.sorted(by: { $0.createdAt > $1.createdAt }), id: \.id) { rec in
                    verificationRow(rec)
                }
            }
            .id(refreshToken)
        }
        .navigationTitle("第 \(ticket.issue) 期")
        .animation(AppMotion.reveal, value: busy)
        .animation(AppMotion.reveal, value: refreshToken)
        .sheet(item: $sheetDraw) { draw in
            DrawVersionSheet(draw: draw, ticket: ticket) { refreshToken += 1 }
                .environment(model)
        }
    }

    private var ticketImage: NSImage? {
        guard let name = ticket.imageFileName,
              let data = imageStore.load(name)
        else { return nil }
        return NSImage(data: data)
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
                Button {
                    sheetDraw = draw
                } label: {
                    Label("开奖版本", systemImage: "square.stack.3d.up")
                }
                .buttonStyle(.glass)
                .interactiveControl()
                .controlSize(.small)
            }
        }
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .hoverLift(scale: 1.006, yOffset: -1, shadowOpacity: 0.08)
    }

    private func reverify(source: DataSourceKind, force: Bool) async {
        busy = true
        overlayCenter.showLoading("验奖中…")
        defer {
            busy = false
            overlayCenter.hideLoading()
        }
        do {
            let version = try await model.fetchService.fetch(category: category, issue: ticket.issue,
                                                             source: source, forceRefresh: force)
            let evaluation = PrizeEvaluator.evaluateTicket(category: category,
                                                           bets: ticket.bets,
                                                           drawFront: version.frontNumbers,
                                                           drawBack: version.backNumbers,
                                                           prizes: version.prizes)
            _ = model.store.addVerification(ticket: ticket, drawVersion: version,
                                            results: evaluation.results, totalAmount: evaluation.totalAmount)
            withAnimation(AppMotion.reveal) {
                refreshToken += 1
            }
            overlayCenter.showToast("已追加验奖记录（\(source.displayName)）", style: .success)
        } catch DrawSourceError.notFound {
            overlayCenter.showToast("该期未开奖或不存在", style: .error)
        } catch DrawSourceError.badResponse(let message) {
            overlayCenter.showToast("错误：\(message)", style: .error)
        } catch {
            overlayCenter.showToast("错误：\(error.localizedDescription)", style: .error)
        }
    }
}

private struct TicketBetNumberRow: View {
    let index: Int
    let bet: Bet
    let showsIndex: Bool

    var body: some View {
        HStack(spacing: 10) {
            if showsIndex {
                Text("第 \(index + 1) 注")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .leading)
            }

            TicketNumberGroup(numbers: bet.front, color: .red)
            TicketNumberGroup(numbers: bet.back, color: .blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.primary.opacity(0.035))
        }
    }
}

private struct TicketNumberGroup: View {
    let numbers: [Int]
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(numbers, id: \.self) { number in
                Text(String(format: "%02d", number))
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(color)
                    .frame(width: 34, height: 30)
                    .background {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(color.opacity(0.12))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(color.opacity(0.45), lineWidth: 1)
                    }
            }
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(color.opacity(0.42),
                        style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.035))
                }
        }
    }
}

private struct TicketInfoCard: View {
    let ticket: Ticket
    let image: NSImage?

    private var category: Category {
        Category(rawValue: ticket.category) ?? .ssq
    }

    var body: some View {
        GlassPanel {
            Label("彩票信息", systemImage: "info.circle")
                .font(.headline)

            HStack(alignment: .top, spacing: 16) {
                ticketPhoto

                VStack(alignment: .leading, spacing: 10) {
                    InfoLine(title: "彩种", value: category.displayName)
                    InfoLine(title: "期号", value: ticket.issue)
                    InfoLine(title: "注数", value: "\(ticket.bets.count) 注")
                    InfoLine(title: "票面金额", value: currencyText(ticket.cost))
                    InfoLine(title: "购票时间", value: dateText(ticket.purchaseDate))
                    InfoLine(title: "创建时间", value: dateText(ticket.createdAt))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder private var ticketPhoto: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .softRevealTransition()
        } else {
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("无照片")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 220, height: 150)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.primary.opacity(0.04))
            }
        }
    }

    private func currencyText(_ value: Double) -> String {
        "¥\(Int(value))"
    }

    private func dateText(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}

private struct InfoLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
        }
    }
}
