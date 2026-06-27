import SwiftUI
import LotteryKit

struct DashboardView: View {
    @Environment(AppModel.self) private var model
    @State private var tickets: [Ticket] = []
    private var summary: StatsSummary { StatsService.summary(StatsService.latestVerifications(tickets)) }

    var body: some View {
        PageScroll {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
                MetricTile(title: "累计投入", value: String(format: "¥%.0f", summary.totalCost), systemImage: "banknote", tint: .blue)
                MetricTile(title: "累计中奖", value: "¥\(summary.totalWin)", systemImage: "trophy", tint: .green)
                MetricTile(title: "净盈亏", value: String(format: "¥%.0f", summary.net), systemImage: "chart.line.uptrend.xyaxis", tint: summary.net >= 0 ? .green : .red)
                MetricTile(title: "中奖率", value: String(format: "%.0f%%", summary.winRate * 100), systemImage: "target", tint: .orange)
            }

            GlassPanel {
                Label("最近彩票", systemImage: "clock")
                    .font(.headline)

                if tickets.isEmpty {
                    Text("暂无彩票记录")
                        .foregroundStyle(.secondary)
                }

                ForEach(tickets.prefix(5), id: \.id) { t in
                    HStack {
                        Label("[\(Category(rawValue: t.category)?.displayName ?? "")] 第 \(t.issue) 期",
                              systemImage: Category(rawValue: t.category)?.symbolName ?? "ticket")
                            .lineLimit(1)
                        Spacer()
                        let amt = t.verifications.max(by: { $0.createdAt < $1.createdAt })?.totalAmount ?? 0
                        Text(amt > 0 ? "¥\(amt)" : "未中奖/待确认")
                            .foregroundStyle(amt > 0 ? .green : .secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("首页")
        .onAppear { tickets = model.store.allTickets() }
    }
}
