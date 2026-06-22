import SwiftUI
import LotteryKit

struct DashboardView: View {
    @EnvironmentObject var model: AppModel
    @State private var tickets: [Ticket] = []
    private var summary: StatsSummary { StatsService.summary(StatsService.latestVerifications(tickets)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("概览").font(.title2).bold()
                HStack(spacing: 16) {
                    card("累计投入", String(format: "¥%.0f", summary.totalCost))
                    card("累计中奖", "¥\(summary.totalWin)")
                    card("净盈亏", String(format: "¥%.0f", summary.net))
                    card("中奖率", String(format: "%.0f%%", summary.winRate * 100))
                }
                Text("最近彩票").font(.headline)
                ForEach(tickets.prefix(5), id: \.id) { t in
                    HStack {
                        Text("[\(Category(rawValue: t.category)?.displayName ?? "")] 第 \(t.issue) 期")
                        Spacer()
                        let amt = t.verifications.max(by: { $0.createdAt < $1.createdAt })?.totalAmount ?? 0
                        Text(amt > 0 ? "¥\(amt)" : "—").foregroundStyle(.secondary)
                    }.padding(8).background(.background.secondary).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Text("快捷操作：左侧「验奖」上传识别；「统计」查看图表；在彩票详情可换源再验或手动改开奖。")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding()
        }
        .navigationTitle("首页")
        .onAppear { tickets = model.store.allTickets() }
    }

    private func card(_ title: String, _ value: String) -> some View {
        VStack { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.title3).bold() }
            .frame(maxWidth: .infinity).padding().background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
