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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 16) {
                    statCard("累计投入", String(format: "¥%.0f", summary.totalCost))
                    statCard("累计中奖", "¥\(summary.totalWin)")
                    statCard("净盈亏", String(format: "¥%.0f", summary.net))
                    statCard("中奖率", String(format: "%.0f%%", summary.winRate * 100))
                }
                groupBox("彩种占比") {
                    Chart(byCategory, id: \.0) { item in
                        SectorMark(angle: .value("数量", item.1), innerRadius: .ratio(0.5))
                            .foregroundStyle(by: .value("彩种", item.0))
                    }.frame(height: 200)
                }
                groupBox("按日购买量") {
                    Chart(byDay, id: \.0) { item in
                        BarMark(x: .value("日期", item.0, unit: .day), y: .value("张数", item.1))
                    }.frame(height: 200)
                }
                groupBox("我的常选红球频率（双色球）") {
                    Chart(freq, id: \.0) { item in
                        BarMark(x: .value("号码", String(item.0)), y: .value("次数", item.1))
                    }.frame(height: 200)
                }
            }.padding()
        }
        .navigationTitle("统计")
        .onAppear { tickets = model.store.allTickets() }
    }

    private func statCard(_ title: String, _ value: String) -> some View {
        VStack { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.title2).bold() }
            .frame(maxWidth: .infinity).padding().background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    private func groupBox<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading) { Text(title).font(.headline); content() }
    }
}
