import SwiftUI

/// The crew lockers: a row of steel lockers, one per foreman. Opening a locker shows that
/// foreman's personnel file with their perk and the hire or "put in the cab" action.
struct CrewLockersView: View {
    @StateObject private var viewModel: CrewLockersViewModel
    let onGround: () -> Void

    init(viewModel: CrewLockersViewModel, onGround: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onGround = onGround
    }

    var body: some View {
        HoistShell(floor: .lockers, onGround: onGround) {
            TiledBackground(texture: "tex_pegsteel")
        } content: {
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Text("Tap a locker to meet the foreman.")
                            .font(.body(15, bold: true))
                            .foregroundStyle(Theme.Colors.concreteLight)
                        Spacer()
                        BoltBadge(amount: viewModel.bolts)
                    }
                    .padding(.horizontal, 16)

                    lockerRow
                    personnelFile
                        .padding(.horizontal, 16)
                        .frame(maxWidth: Theme.Metrics.maxContentWidth)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }
        }
        .toast(message: $viewModel.message, isError: viewModel.messageIsError)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Lockers.screen)
    }

    // MARK: - Lockers

    private var lockerRow: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Foreman.allCases) { foreman in
                        locker(foreman).id(foreman)
                    }
                }
                .padding(.horizontal, 16)
            }
            .onAppear { proxy.scrollTo(viewModel.opened, anchor: .center) }
        }
        .frame(height: lockerHeight + 30)
    }

    private let lockerWidth: CGFloat = 84
    private var lockerHeight: CGFloat { lockerWidth * 2.16 }

    private func locker(_ foreman: Foreman) -> some View {
        let isOpen = viewModel.opened == foreman
        let hired = viewModel.isHired(foreman)
        return Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { viewModel.open(foreman) } } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .top) {
                    ArtImage(isOpen ? "locker_open" : "locker_closed")
                    // Portrait taped to the door, or hanging inside when open.
                    ArtImage(foreman.portraitArt)
                        .frame(width: lockerWidth * 0.6, height: lockerWidth * 0.6)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.Colors.ink, lineWidth: 1.5))
                        .saturation(hired ? 1 : 0.2)
                        .padding(.top, isOpen ? lockerHeight * 0.06 : lockerHeight * 0.18)
                    if !hired {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.Colors.hiVis)
                            .padding(6)
                            .background(Circle().fill(Theme.Colors.ink))
                            .padding(.top, lockerHeight * 0.55)
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: lockerWidth, height: lockerHeight)
                .offset(y: isOpen ? -8 : 0)

                Text(foreman.name)
                    .font(.display(15, relativeTo: .caption))
                    .foregroundStyle(isOpen ? Theme.Colors.hiVis : Theme.Colors.concreteLight)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if viewModel.onShift == foreman {
                    Text("IN CAB")
                        .font(.display(11))
                        .foregroundStyle(Theme.Colors.ink)
                        .padding(.horizontal, 6)
                        .background(Capsule().fill(Theme.Colors.hiVis))
                }
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(foreman.name), \(foreman.trade)")
        .accessibilityValue(hired ? (viewModel.onShift == foreman ? "In the cab" : "Hired") : "\(Formatters.integer(foreman.price)) bolts to hire")
        .accessibilityAddTraits(isOpen ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(AccessibilityID.Lockers.locker(foreman))
    }

    // MARK: - Personnel file

    private var personnelFile: some View {
        let foreman = viewModel.opened
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                ArtImage(foreman.portraitArt)
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.Colors.ink, lineWidth: 2))
                VStack(alignment: .leading, spacing: 4) {
                    Text("PERSONNEL FILE")
                        .font(.typed(11, bold: true))
                        .foregroundStyle(Theme.Colors.inkSoft)
                    Text(foreman.name)
                        .font(.display(28, relativeTo: .title))
                        .foregroundStyle(Theme.Colors.ink)
                        .accessibilityIdentifier(AccessibilityID.Lockers.selectedName)
                    Text(foreman.trade)
                        .font(.typed(15))
                        .foregroundStyle(Theme.Colors.inkSoft)
                }
            }
            Divider().overlay(Theme.Colors.ink.opacity(0.4))
            VStack(alignment: .leading, spacing: 4) {
                Text("Perk: \(foreman.perkTitle)")
                    .font(.body(17, bold: true))
                    .foregroundStyle(Theme.Colors.safetyGreen)
                Text(foreman.perkDetail)
                    .font(.body(15))
                    .foregroundStyle(Theme.Colors.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            actionButton
        }
        .padding(16)
        .background { ManilaBackground() }
        .animation(.easeOut(duration: 0.25), value: foreman)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch viewModel.action {
        case .hire(let price, let affordable):
            Button { viewModel.performAction() } label: {
                HStack(spacing: 6) {
                    Text("Hire for")
                    ArtImage("icon_bolt").frame(width: 20, height: 20)
                    Text(Formatters.integer(price)).monospacedDigit()
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(HiVisButtonStyle(tint: affordable ? Theme.Colors.hiVis : Theme.Colors.concrete, isProminent: false))
            .accessibilityLabel("Hire \(viewModel.opened.name) for \(Formatters.integer(price)) bolts")
            .accessibilityIdentifier(AccessibilityID.Lockers.action)
        case .assign:
            Button("Put in the cab") { viewModel.performAction() }
                .buttonStyle(HiVisButtonStyle(isProminent: false))
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier(AccessibilityID.Lockers.action)
        case .onShift:
            Label("In the cab for the next shift", systemImage: "checkmark.circle.fill")
                .font(.body(16, bold: true))
                .foregroundStyle(Theme.Colors.safetyGreen)
                .frame(maxWidth: .infinity, minHeight: Theme.Metrics.minimumTap)
                .accessibilityIdentifier(AccessibilityID.Lockers.action)
        }
    }
}
