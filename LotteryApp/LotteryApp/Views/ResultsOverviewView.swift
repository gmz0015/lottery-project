import SwiftUI
import LotteryKit

struct ResultsOverviewView: View {
    @Environment(AppModel.self) private var model
    @State private var stats: [TicketStat] = []
    @State private var filter: String = "all"

    var filtered: [TicketStat] {
        filter == "all" ? stats : stats.filter { $0.ticket.category == filter }
    }

    var body: some View {
        VStack(spacing: 0) {
            ContentBar(title: "最新结果", detail: "\(filtered.count) 条", systemImage: "checkmark.seal") {
                Picker("彩种", selection: $filter) {
                    Text("全部").tag("all")
                    Text("双色球").tag(Category.ssq.rawValue)
                    Text("大乐透").tag(Category.dlt.rawValue)
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
                .accessibilityIdentifier("categoryFilterPicker")
            }

            Divider()

            if stats.isEmpty {
                PageScroll {
                    EmptyState(title: "暂无验奖结果", message: "完成验奖后，可在这里按彩种查看最新结果。", systemImage: "checkmark.seal")
                }
            } else {
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
                .scrollContentBackground(.hidden)
                .background(.regularMaterial)
            }
        }
        .background(.regularMaterial)
        .navigationTitle("验奖结果总览")
        .animation(AppMotion.reveal, value: filtered.count)
        .onAppear {
            withAnimation(AppMotion.reveal) {
                stats = StatsService.latestVerifications(model.store.allTickets())
            }
        }
    }
}
