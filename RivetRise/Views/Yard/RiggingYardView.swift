import SwiftUI

/// The rigging yard: every crane upgrade hangs as a load from its own hook on a steel cable.
/// A manila job tag next to the load shows the level stripes, the effect and the HOIST button.
struct RiggingYardView: View {
    @StateObject private var viewModel: RiggingYardViewModel
    let onGround: () -> Void

    init(viewModel: RiggingYardViewModel, onGround: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onGround = onGround
    }

    var body: some View {
        HoistShell(floor: .yard, onGround: onGround) {
            TiledBackground(texture: "tex_concrete", tint: Color.black.opacity(0.15))
        } content: {
            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        Text("Spend bolts on permanent crane upgrades.")
                            .font(.body(15, bold: true))
                            .foregroundStyle(Theme.Colors.concreteLight)
                        Spacer()
                        BoltBadge(amount: viewModel.bolts)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.rows) { row in
                            HookRow(row: row, bounced: viewModel.lastHoisted == row.kind) {
                                viewModel.hoist(row.kind)
                            }
                        }
                    }
                }
                .frame(maxWidth: Theme.Metrics.maxContentWidth)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 24)
            }
        }
        .toast(message: $viewModel.message, isError: viewModel.messageIsError)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Yard.screen)
    }
}

private struct HookRow: View {
    let row: RiggingYardViewModel.Row
    let bounced: Bool
    let onHoist: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // The load on its cable.
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Theme.Colors.ink)
                    .frame(width: 3, height: 18)
                ArtImage(row.kind.art)
                    .frame(width: 112, height: 124)
                    .offset(y: bounced ? -10 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.4), value: bounced)
            }
            .frame(width: 124)

            tag
                .padding(.top, 26)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    private var tag: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.kind.title)
                    .font(.display(20, relativeTo: .headline))
                    .foregroundStyle(Theme.Colors.ink)
                Spacer(minLength: 4)
                Text(row.isMaxed ? "MAX" : "LV \(row.level)")
                    .font(.typed(13, bold: true))
                    .foregroundStyle(Theme.Colors.inkSoft)
                    .accessibilityIdentifier(AccessibilityID.Yard.level(row.kind))
                    .accessibilityLabel("Level \(row.level) of \(row.kind.maxLevel)")
            }
            LevelStripes(level: row.level, maxLevel: row.kind.maxLevel)
            Text(row.kind.summary)
                .font(.body(14))
                .foregroundStyle(Theme.Colors.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 4) {
                Text(row.currentEffect)
                if let next = row.nextEffect {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .accessibilityHidden(true)
                    Text(next).foregroundStyle(Theme.Colors.safetyGreen)
                }
            }
            .font(.typed(13, bold: true))
            .foregroundStyle(Theme.Colors.inkSoft)
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            hoistButton
        }
        .padding(12)
        .background { ManilaBackground(cornerRadius: 6) }
        .overlay(alignment: .topLeading) {
            // The tag's eyelet and string tie it to the load's sling.
            Circle()
                .strokeBorder(Theme.Colors.ink, lineWidth: 2)
                .background(Circle().fill(Theme.Colors.concrete))
                .frame(width: 12, height: 12)
                .offset(x: -4, y: 10)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var hoistButton: some View {
        if let cost = row.cost {
            Button(action: onHoist) {
                HStack(spacing: 6) {
                    Text("Hoist")
                    ArtImage("icon_bolt").frame(width: 18, height: 18)
                    Text(Formatters.integer(cost)).monospacedDigit()
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(HiVisButtonStyle(tint: row.canAfford ? Theme.Colors.hiVis : Theme.Colors.concrete, isProminent: false))
            .accessibilityLabel("Hoist \(row.kind.title) for \(Formatters.integer(cost)) bolts")
            .accessibilityValue(row.canAfford ? "Affordable" : "Not enough bolts")
            .accessibilityIdentifier(AccessibilityID.Yard.hoist(row.kind))
        } else {
            Text("Full spec")
                .font(.display(17))
                .foregroundStyle(Theme.Colors.safetyGreen)
                .frame(maxWidth: .infinity, minHeight: Theme.Metrics.minimumTap)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.Colors.safetyGreen, style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
                .accessibilityIdentifier(AccessibilityID.Yard.hoist(row.kind))
        }
    }
}
