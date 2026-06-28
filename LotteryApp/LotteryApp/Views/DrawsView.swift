import SwiftUI
import LotteryKit

struct DrawsView: View {
    @Environment(AppModel.self) private var model
    @State private var draws: [Draw] = []
    @State private var categoryFilter = "all"
    @State private var sourceFilter = "all"
    @State private var status = ""
    @State private var refreshingDrawID: UUID?
    @State private var entrySheetMode: DrawEntrySheet.Mode?

    private var filteredDraws: [Draw] {
        draws.filter { draw in
            (categoryFilter == "all" || draw.category == categoryFilter)
            && (sourceFilter == "all" || draw.source == sourceFilter)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ContentBar(title: "开奖信息", detail: "\(filteredDraws.count) 期", systemImage: "number.square") {
                Picker("彩种", selection: $categoryFilter) {
                    Text("全部").tag("all")
                    ForEach(Category.allCases, id: \.self) { category in
                        Text(category.displayName).tag(category.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                Picker("来源", selection: $sourceFilter) {
                    Text("全部来源").tag("all")
                    ForEach(DataSourceKind.allCases, id: \.self) { source in
                        Text(source.displayName).tag(source.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 135)

                Button {
                    entrySheetMode = .manual
                } label: {
                    Image(systemName: "square.and.pencil")
                        .frame(width: 22, height: 20)
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .interactiveControl()
                .help("手动录入开奖")
                .accessibilityLabel("手动录入开奖")

                Button {
                    entrySheetMode = .fetch
                } label: {
                    Image(systemName: "arrow.down.doc")
                        .frame(width: 22, height: 20)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.small)
                .interactiveControl()
                .help("拉取指定期开奖")
                .accessibilityLabel("拉取指定期开奖")

                Button {
                    reloadDraws()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 22, height: 20)
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .interactiveControl()
                .help("刷新列表")
                .accessibilityLabel("刷新列表")
                .accessibilityIdentifier("reloadDrawsButton")
            }

            Divider()

            if draws.isEmpty {
                PageScroll {
                    EmptyState(title: "暂无开奖信息",
                               message: "验奖、手动录入或刷新某一期后，可在这里查看各数据源返回的开奖号码和版本。",
                               systemImage: "number.square")
                }
            } else {
                VStack(spacing: 0) {
                    if !status.isEmpty {
                        StatusBanner(text: status)
                            .padding(.horizontal, 20)
                            .padding(.top, 14)
                    }

                    Table(filteredDraws) {
                        TableColumn("彩种") { draw in
                            Label(categoryName(draw), systemImage: categoryIcon(draw))
                        }

                        TableColumn("期数") { draw in
                            Text(draw.issue)
                                .monospacedDigit()
                        }

                        TableColumn("来源") { draw in
                            Text(sourceName(draw))
                        }

                        TableColumn("开奖号码") { draw in
                            if let version = model.store.latestVersion(draw) {
                                HStack(spacing: 8) {
                                    NumberBadges(numbers: version.frontNumbers, color: .red)
                                    NumberBadges(numbers: version.backNumbers, color: .blue)
                                }
                            } else {
                                Text("—")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        TableColumn("版本") { draw in
                            if let version = model.store.latestVersion(draw) {
                                Text("v\(version.versionNumber) · \(originName(version.origin))")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("—")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        TableColumn("开奖日期") { draw in
                            if let date = model.store.latestVersion(draw)?.drawDate {
                                Text(Self.dateFormatter.string(from: date))
                            } else {
                                Text("—")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        TableColumn("奖金信息") { draw in
                            Text(prizeSummary(model.store.latestVersion(draw)?.prizes))
                                .lineLimit(1)
                        }

                        TableColumn("操作") { draw in
                            HStack(spacing: 10) {
                                if let url = sourceURL(draw) {
                                    Link(destination: url) {
                                        Image(systemName: "link")
                                    }
                                    .interactiveControl()
                                    .help("打开来源页")
                                }

                                Button {
                                    Task { await refresh(draw) }
                                } label: {
                                    if refreshingDrawID == draw.id {
                                        ProgressView()
                                            .controlSize(.small)
                                            .softRevealTransition()
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .softRevealTransition()
                                    }
                                }
                                .buttonStyle(.borderless)
                                .interactiveControl()
                                .help("从该数据源强制刷新本期")
                                .disabled(!canRefresh(draw) || refreshingDrawID != nil)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(.regularMaterial)
                }
            }
        }
        .background(.regularMaterial)
        .navigationTitle("开奖信息")
        .animation(AppMotion.reveal, value: draws.count)
        .animation(AppMotion.reveal, value: status)
        .animation(AppMotion.reveal, value: refreshingDrawID)
        .onAppear(perform: reloadDraws)
        .sheet(item: $entrySheetMode) { mode in
            DrawEntrySheet(initialMode: mode) {
                reloadDraws()
            }
        }
    }

    private func reloadDraws() {
        withAnimation(AppMotion.reveal) {
            draws = model.store.allDraws()
        }
    }

    private func refresh(_ draw: Draw) async {
        guard let category = Category(rawValue: draw.category),
              let source = DataSourceKind(rawValue: draw.source) else {
            status = "错误：开奖记录的彩种或来源无效"
            return
        }
        let issue = draw.issue
        withAnimation(AppMotion.reveal) {
            refreshingDrawID = draw.id
            status = "正在刷新 \(category.displayName) 第 \(issue) 期"
        }
        defer {
            withAnimation(AppMotion.reveal) {
                refreshingDrawID = nil
            }
        }

        do {
            _ = try await model.fetchService.fetch(category: category, issue: issue, source: source, forceRefresh: true)
            reloadDraws()
            withAnimation(AppMotion.reveal) {
                status = "已刷新 \(category.displayName) 第 \(issue) 期"
            }
        } catch DrawSourceError.notFound {
            withAnimation(AppMotion.reveal) {
                status = "错误：该期未开奖或不存在"
            }
        } catch {
            withAnimation(AppMotion.reveal) {
                status = "错误：\(error.localizedDescription)"
            }
        }
    }

    private func canRefresh(_ draw: Draw) -> Bool {
        guard let source = DataSourceKind(rawValue: draw.source),
              let category = Category(rawValue: draw.category) else { return false }
        return source != .manual && model.availableSources(for: category).contains(source)
    }

    private func categoryName(_ draw: Draw) -> String {
        Category(rawValue: draw.category)?.displayName ?? draw.category
    }

    private func categoryIcon(_ draw: Draw) -> String {
        Category(rawValue: draw.category)?.symbolName ?? "number.square"
    }

    private func sourceName(_ draw: Draw) -> String {
        DataSourceKind(rawValue: draw.source)?.displayName ?? draw.source
    }

    private func originName(_ origin: String) -> String {
        origin == "fetched" ? "抓取" : "手动"
    }

    private func sourceURL(_ draw: Draw) -> URL? {
        guard let urlString = model.store.latestVersion(draw)?.sourceURL else { return nil }
        return URL(string: urlString)
    }

    private func prizeSummary(_ prizes: [String: Int]?) -> String {
        guard let prizes, !prizes.isEmpty else { return "—" }
        let parts = prizes.sorted(by: { $0.key < $1.key }).prefix(3).map { key, amount in
            "\(key) \(Self.amountFormatter.string(from: NSNumber(value: amount)) ?? "\(amount)")"
        }
        let suffix = prizes.count > 3 ? " 等" : ""
        return parts.joined(separator: "，") + suffix
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let amountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}
