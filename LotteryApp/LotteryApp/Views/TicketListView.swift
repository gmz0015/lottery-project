import SwiftUI
import LotteryKit

struct TicketListView: View {
    @Environment(AppModel.self) private var model
    @State private var tickets: [Ticket] = []

    var body: some View {
        VStack(spacing: 0) {
            ContentBar(title: "保存的彩票", detail: "\(tickets.count) 张", systemImage: "ticket") {
                Button {
                    reload()
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            }

            Divider()

            if tickets.isEmpty {
                PageScroll {
                    EmptyState(title: "暂无彩票", message: "在“验奖”页面录入或识别一张彩票后，会自动保存到这里。", systemImage: "ticket")
                }
            } else {
                List(tickets, id: \.id) { t in
                    NavigationLink(value: t.id) {
                        HStack(spacing: 10) {
                            Image(systemName: Category(rawValue: t.category)?.symbolName ?? "ticket")
                                .foregroundStyle(.secondary)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("[\(Category(rawValue: t.category)?.displayName ?? t.category)] 第 \(t.issue) 期")
                                    .lineLimit(1)
                                let latest = t.verifications.max(by: { $0.createdAt < $1.createdAt })
                                Text(latest.map { $0.totalAmount > 0 ? "最近：中奖 ¥\($0.totalAmount)" : "最近：未中奖/待确认" } ?? "未验奖")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .background(.regularMaterial)
            }
        }
        .background(.regularMaterial)
        .navigationTitle("彩票列表")
        .navigationDestination(for: UUID.self) { id in
            if let t = tickets.first(where: { $0.id == id }) { TicketDetailView(ticket: t) }
        }
        .onAppear { reload() }
    }

    private func reload() {
        tickets = model.store.allTickets()
    }
}
