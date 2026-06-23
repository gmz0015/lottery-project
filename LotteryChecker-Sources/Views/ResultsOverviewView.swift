import SwiftUI
import LotteryKit

struct ResultsOverviewView: View {
    @EnvironmentObject var model: AppModel
    @State private var stats: [TicketStat] = []
    @State private var filter: String = "all"

    var filtered: [TicketStat] {
        filter == "all" ? stats : stats.filter { $0.ticket.category == filter }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Picker("彩种", selection: $filter) {
                Text("全部").tag("all")
                Text("双色球").tag("ssq")
                Text("大乐透").tag("dlt")
            }.pickerStyle(.segmented).frame(maxWidth: 300)
            Table(filtered) {
                TableColumn("彩种") { s in Text(Category(rawValue: s.ticket.category)?.displayName ?? "") }
                TableColumn("期数") { s in Text(s.ticket.issue) }
                TableColumn("最新结果") { s in
                    let amt = s.latest?.totalAmount ?? 0
                    let win = s.latest?.results.contains { $0.result.isWin } ?? false
                    Text(s.latest == nil ? "未验奖" : (amt > 0 ? "中奖 ¥\(amt)" : (win ? "中奖(待定金额)" : "未中奖")))
                        .foregroundStyle(win ? .green : .secondary)
                }
                TableColumn("来源") { s in
                    Text(s.latest?.drawVersion?.draw.map { DataSourceKind(rawValue: $0.source)?.displayName ?? "" } ?? "—")
                }
            }
        }
        .padding()
        .navigationTitle("验奖结果总览")
        .onAppear { stats = StatsService.latestVerifications(model.store.allTickets()) }
    }
}
