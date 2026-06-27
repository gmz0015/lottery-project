import SwiftUI
import LotteryKit

struct TicketListView: View {
    @Environment(AppModel.self) private var model
    @State private var tickets: [Ticket] = []

    var body: some View {
        List(tickets, id: \.id) { t in
            NavigationLink(value: t.id) {
                VStack(alignment: .leading) {
                    Text("[\(Category(rawValue: t.category)?.displayName ?? t.category)] 第 \(t.issue) 期").bold()
                    let latest = t.verifications.max(by: { $0.createdAt < $1.createdAt })
                    Text(latest.map { $0.totalAmount > 0 ? "最近：中奖 ¥\($0.totalAmount)" : "最近：未中奖/待确认" } ?? "未验奖")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("彩票列表")
        .navigationDestination(for: UUID.self) { id in
            if let t = tickets.first(where: { $0.id == id }) { TicketDetailView(ticket: t) }
        }
        .onAppear { tickets = model.store.allTickets() }
    }
}
