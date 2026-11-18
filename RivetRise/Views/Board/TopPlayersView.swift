import SwiftUI

/// TOP PLAYERS: the weekly building league. A native league plate and tab switch sit on top;
/// "Top 5" is the bundled HTML board in a web view, "Site Orders" are the weekly tasks.
struct TopPlayersView: View {
    @StateObject private var viewModel: TopPlayersViewModel
    let onGround: () -> Void

    init(viewModel: TopPlayersViewModel, onGround: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onGround = onGround
    }

    var body: some View {
        HoistShell(floor: .board, onGround: onGround) {
            TiledBackground(texture: "tex_pegsteel")
        } content: {
            VStack(spacing: 12) {
                leaguePlate
                Picker("Section", selection: $viewModel.tab) {
                    ForEach(TopPlayersViewModel.Tab.allCases) { tab in
                        Text(tab == .orders && viewModel.readyOrders > 0 ? "\(tab.rawValue) (\(viewModel.readyOrders))" : tab.rawValue)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier(AccessibilityID.Board.tabs)

                switch viewModel.tab {
                case .board:
                    BoardWebView(board: viewModel.board) { viewModel.tapRewardSlot($0) }
                        .overlay {
                            if viewModel.board == nil {
                                ProgressView().tint(Theme.Colors.hiVis)
                            }
                        }
                        .accessibilityIdentifier(AccessibilityID.Board.web)
                case .orders:
                    orders
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .frame(maxWidth: Theme.Metrics.maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .task { await viewModel.load() }
        .toast(message: $viewModel.message, isError: viewModel.messageIsError)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Board.screen)
    }

    // MARK: - League plate

    private var leaguePlate: some View {
        HStack(spacing: 12) {
            ArtImage("pict_board")
                .frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.league.title)
                    .font(.display(21, relativeTo: .headline))
                    .foregroundStyle(Theme.Colors.ink)
                    .accessibilityIdentifier(AccessibilityID.Board.league)
                Text("Week best \(viewModel.weeklyBest) floors · \(viewModel.leagueProgressText)")
                    .font(.typed(13))
                    .foregroundStyle(Theme.Colors.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background { HiVisPlate() }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Weekly site orders

    private var orders: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("New orders every Monday. Each pays once per week.")
                    .font(.body(14, bold: true))
                    .foregroundStyle(Theme.Colors.concreteLight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(viewModel.orders) { status in
                    orderCard(status)
                }
            }
            .padding(.bottom, 24)
        }
        .accessibilityIdentifier(AccessibilityID.Board.orders)
    }

    private func orderCard(_ status: WeeklyOrderStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(status.order.title)
                    .font(.display(19, relativeTo: .headline))
                    .foregroundStyle(Theme.Colors.ink)
                Spacer()
                HStack(spacing: 4) {
                    ArtImage("icon_bolt").frame(width: 18, height: 18)
                    Text("\(status.order.reward)").font(.display(17)).foregroundStyle(Theme.Colors.ink)
                }
            }
            Text(status.order.detail)
                .font(.body(15))
                .foregroundStyle(Theme.Colors.ink)
            ProgressView(value: status.fraction)
                .tint(status.isComplete ? Theme.Colors.safetyGreen : Theme.Colors.hiVisDeep)
            HStack {
                Text("\(min(status.progress, status.order.target)) / \(status.order.target)")
                    .font(.typed(14, bold: true))
                    .foregroundStyle(Theme.Colors.inkSoft)
                Spacer()
                if status.isClaimed {
                    Label("Paid", systemImage: "checkmark.circle.fill")
                        .font(.body(15, bold: true))
                        .foregroundStyle(Theme.Colors.safetyGreen)
                } else {
                    Button("Collect") { viewModel.claim(status) }
                        .buttonStyle(HiVisButtonStyle(tint: status.canClaim ? Theme.Colors.hiVis : Theme.Colors.concrete, isProminent: false))
                        .accessibilityValue(status.canClaim ? "Ready" : "Not finished")
                }
            }
        }
        .padding(12)
        .background { ManilaBackground(cornerRadius: 6) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Board.order(status.order.id))
    }
}
