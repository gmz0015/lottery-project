import SwiftUI
import Charts
import LotteryKit

struct StatsView: View {
    @Environment(AppModel.self) private var model
    @State private var tickets: [Ticket] = []

    private var summary: StatsSummary { StatsService.summary(StatsService.latestVerifications(tickets)) }
    private var byCategory: [(String, Int)] {
        StatsService.countByCategory(tickets).map { ($0.key.displayName, $0.value) }
    }
    private var byDay: [(Date, Int)] {
        StatsService.purchasesByDay(tickets).sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }
    private var freq: [(Int, Int)] {
        StatsService.myNumberFrequency(tickets, category: .ssq).sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    var body: some View {
        PageScroll {
            Text("统计")
                .font(.largeTitle.weight(.semibold))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
                MetricTile(title: "累计投入", value: String(format: "¥%.0f", summary.totalCost), systemImage: "banknote", tint: .blue)
                MetricTile(title: "累计中奖", value: "¥\(summary.totalWin)", systemImage: "trophy", tint: .green)
                MetricTile(title: "净盈亏", value: String(format: "¥%.0f", summary.net), systemImage: "chart.line.uptrend.xyaxis", tint: summary.net >= 0 ? .green : .red)
                MetricTile(title: "中奖率", value: String(format: "%.0f%%", summary.winRate * 100), systemImage: "target", tint: .orange)
            }

            if tickets.isEmpty {
                EmptyState(title: "暂无统计数据", message: "完成一次验奖后，这里会显示购买、中奖和号码频率。", systemImage: "chart.xyaxis.line")
            } else {
                chartPanel("彩种占比", systemImage: "chart.pie") {
                    Chart(byCategory, id: \.0) { item in
                        SectorMark(angle: .value("数量", item.1), innerRadius: .ratio(0.5))
                            .foregroundStyle(by: .value("彩种", item.0))
                    }
                    .frame(height: 220)
                }

                chartPanel("按日购买量", systemImage: "calendar") {
                    Chart(byDay, id: \.0) { item in
                        BarMark(x: .value("日期", item.0, unit: .day), y: .value("张数", item.1))
                    }
                    .frame(height: 220)
                }

                chartPanel("我的常选红球频率（双色球）", systemImage: "number.circle") {
                    Chart(freq, id: \.0) { item in
                        BarMark(x: .value("号码", String(item.0)), y: .value("次数", item.1))
                    }
                    .frame(height: 220)
                }
            }
        }
        .navigationTitle("统计")
        .onAppear { tickets = model.store.allTickets() }
    }

    private func chartPanel<C: View>(_ title: String, systemImage: String, @ViewBuilder _ content: @escaping () -> C) -> some View {
        GlassPanel {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content()
        }
    }
}
