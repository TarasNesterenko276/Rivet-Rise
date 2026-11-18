import SwiftUI

/// The home screen: a building site at dawn. The time clock starts a shift; the yellow hoist
/// pendant at the bottom sends the hoist to every other part of the site.
struct SiteView: View {
    @StateObject private var viewModel: SiteViewModel
    let animates: Bool
    let onOpen: (SiteFloor) -> Void
    let onClockIn: () -> Void

    @State private var cardPunched = false

    init(viewModel: SiteViewModel, animates: Bool, onOpen: @escaping (SiteFloor) -> Void, onClockIn: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.animates = animates
        self.onOpen = onOpen
        self.onClockIn = onClockIn
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 12)
            HStack(alignment: .bottom, spacing: 18) {
                foremanTag
                Spacer(minLength: 0)
                timeClock
            }
            .padding(.horizontal, 20)
            pendant
                .padding(.top, 18)
        }
        .frame(maxWidth: Theme.Metrics.maxContentWidth)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
        .background {
            GeometryReader { proxy in
                Image("bg_site")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
                    .clipped()
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Site.screen)
    }

    // MARK: - Header: wordmark beam, bolts and best height

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()
                BoltBadge(amount: viewModel.bolts)
                    .accessibilityIdentifier(AccessibilityID.Site.bolts)
            }
            ArtImage("logo")
                .frame(maxWidth: 340)
                .accessibilityLabel("Rivet Rise")
                .accessibilityHidden(false)
                .accessibilityAddTraits(.isHeader)
            Text(viewModel.bestLine)
                .font(.typed(15, bold: true))
                .foregroundStyle(Theme.Colors.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background { ManilaBackground(cornerRadius: 4) }
                .rotationEffect(.degrees(-2))
                .accessibilityIdentifier(AccessibilityID.Site.best)
            if let error = viewModel.persistenceError {
                Text(error)
                    .font(.body(14, bold: true))
                    .foregroundStyle(Theme.Colors.danger)
                    .padding(8)
                    .background { ManilaBackground(cornerRadius: 6) }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Foreman on shift

    private var foremanTag: some View {
        Button { onOpen(.lockers) } label: {
            VStack(spacing: 6) {
                ArtImage(viewModel.foreman.portraitArt)
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.Colors.ink, lineWidth: 2))
                VStack(spacing: 1) {
                    Text("On shift")
                        .font(.typed(11))
                        .foregroundStyle(Theme.Colors.inkSoft)
                    Text(viewModel.foreman.name)
                        .font(.display(17, relativeTo: .headline))
                        .foregroundStyle(Theme.Colors.ink)
                    Text(viewModel.foreman.perkTitle)
                        .font(.body(12, bold: true))
                        .foregroundStyle(Theme.Colors.safetyGreen)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background { ManilaBackground(cornerRadius: 6) }
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Foreman on shift: \(viewModel.foreman.name), \(viewModel.foreman.perkTitle)")
        .accessibilityHint("Opens the crew lockers")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(AccessibilityID.Site.foreman)
    }

    // MARK: - Time clock (main action)

    private var timeClock: some View {
        Button {
            viewModel.punchCard()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { cardPunched = true }
            Task {
                try? await Task.sleep(nanoseconds: 260_000_000)
                cardPunched = false
                onClockIn()
            }
        } label: {
            ZStack(alignment: .top) {
                ArtImage("punch_card")
                    .frame(width: 92)
                    .offset(y: cardPunched ? 46 : 0)
                ArtImage("time_clock")
                    .frame(width: 140)
                    .overlay(alignment: .top) { secondHand }
                    .padding(.top, 26)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Clock in")
        .accessibilityHint("Starts a shift on the crane")
        .accessibilityIdentifier(AccessibilityID.Site.clockIn)
    }

    /// The red second hand ticks while the site screen is visible.
    @ViewBuilder
    private var secondHand: some View {
        if animates {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let seconds = Calendar.current.component(.second, from: context.date)
                Capsule()
                    .fill(Theme.Colors.danger)
                    .frame(width: 2, height: 26)
                    .offset(y: -13)
                    .rotationEffect(.degrees(Double(seconds) * 6))
                    .frame(width: 2, height: 2)
                    .padding(.top, 45)
                    .animation(.spring(response: 0.2, dampingFraction: 0.5), value: seconds)
            }
            .accessibilityHidden(true)
        }
    }

    // MARK: - Hoist pendant

    private var pendant: some View {
        VStack(spacing: 0) {
            // The cable the pendant hangs from.
            Rectangle()
                .fill(Theme.Colors.ink)
                .frame(width: 4, height: 18)
            HStack(spacing: 4) {
                ForEach(SiteFloor.allCases) { floor in
                    pendantButton(floor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .background { HiVisPlate() }
            .overlay(alignment: .top) {
                Text("HOIST CONTROL")
                    .font(.display(11))
                    .letterSpacing(2)
                    .foregroundStyle(Theme.Colors.ink)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 12)
    }

    private func pendantButton(_ floor: SiteFloor) -> some View {
        Button { onOpen(floor) } label: {
            VStack(spacing: 6) {
                ArtImage(floor.pictogram)
                    .frame(width: 34, height: 34)
                    .frame(width: 54, height: 54)
                    .background(PendantCap())
                    .overlay(alignment: .topTrailing) {
                        if floor == .yard, viewModel.affordableUpgrades > 0 {
                            Circle()
                                .fill(Theme.Colors.safetyGreen)
                                .overlay(Circle().strokeBorder(Theme.Colors.ink, lineWidth: 1.5))
                                .frame(width: 14, height: 14)
                                .accessibilityHidden(true)
                        }
                    }
                Text(floor.buttonLabel)
                    .font(.display(14, relativeTo: .caption))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Colors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(floor.title)
        .accessibilityHint(floor.hint)
        .accessibilityIdentifier(AccessibilityID.Site.floorButton(floor))
    }
}

/// The round rubber-booted cap behind each pendant pictogram.
private struct PendantCap: View {
    var body: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.85)).offset(y: 3)
            Circle()
                .fill(RadialGradient(colors: [Theme.Colors.concreteLight, Theme.Colors.concrete, Theme.Colors.graphite.opacity(0.9)], center: .init(x: 0.35, y: 0.3), startRadius: 2, endRadius: 40))
                .overlay(Circle().strokeBorder(Theme.Colors.ink, lineWidth: 2))
        }
        .accessibilityHidden(true)
    }
}
