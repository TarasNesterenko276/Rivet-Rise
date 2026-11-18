import SwiftUI

/// The in-shift HUD: a steel beam scoreboard and pause pendant on top, the weathervane,
/// next-module tag and shift badge under it, a height tape on the right edge, and the
/// hard hats and Rush gauge at the bottom. The plumb bob is drawn by the scene.
struct GameHUDView: View {
    let hud: GameHUDState
    let callout: GameViewModel.Callout?
    let shiftBanner: SiteShift?
    let bestFloors: Int
    let isVisible: Bool
    let onPause: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            scoreBeam
            HStack(alignment: .top) {
                weathervane
                Spacer()
                nextModule
            }
            .padding(.horizontal, 12)
            calloutView
            Spacer()
            bottomBar
        }
        .overlay(alignment: .trailing) { heightTape }
        .overlay { banner }
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .animation(.easeOut(duration: 0.2), value: isVisible)
    }

    // MARK: - Top

    private var scoreBeam: some View {
        HStack(spacing: 10) {
            Button(action: onPause) {
                Image(systemName: "pause.fill")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Theme.Colors.ink)
            }
            .buttonStyle(PendantButtonStyle(diameter: 46))
            .accessibilityLabel("Pause")
            .accessibilityIdentifier(AccessibilityID.Game.pause)

            VStack(alignment: .leading, spacing: 0) {
                Text("FLOOR")
                    .font(.display(11))
                    .letterSpacing(1.5)
                    .foregroundStyle(Theme.Colors.concrete)
                Text("\(hud.floors)")
                    .font(.system(size: 30, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Theme.Colors.led)
                    .shadow(color: Theme.Colors.led.opacity(0.7), radius: 5)
                    .numericTransition()
            }
            .frame(minWidth: 62, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Floors")
            .accessibilityValue("\(hud.floors)")
            .accessibilityIdentifier(AccessibilityID.Game.floors)

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 0) {
                Text("POINTS")
                    .font(.display(11))
                    .letterSpacing(1.5)
                    .foregroundStyle(Theme.Colors.concrete)
                Text(Formatters.integer(hud.score))
                    .font(.display(28, relativeTo: .title))
                    .foregroundStyle(Theme.Colors.hiVis)
                    .monospacedDigit()
                    .numericTransition()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Points")
            .accessibilityValue(Formatters.integer(hud.score))
            .accessibilityIdentifier(AccessibilityID.Game.score)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background { BeamPlate() }
        .padding(.horizontal, 10)
        .padding(.top, 4)
        .animation(.easeOut(duration: 0.25), value: hud.score)
    }

    private var weathervane: some View {
        let warning = hud.wind.isWarning
        let gusting = hud.wind.isGusting
        let direction = hud.wind.direction
        return HStack(spacing: 6) {
            ArtImage("weathervane")
                .frame(width: 48, height: 48)
                .rotationEffect(.degrees(direction < 0 ? 180 : 0))
                .rotationEffect(.degrees(warning || gusting ? 0 : 90))
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: hud.wind)
            Text(gusting ? "GUST!" : warning ? "WIND\nRISING" : "CALM")
                .font(.display(13))
                .foregroundStyle(gusting || warning ? Theme.Colors.ink : Theme.Colors.inkSoft)
                .multilineTextAlignment(.leading)
                .fixedSize()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(gusting ? Theme.Colors.danger.opacity(0.9) : warning ? Theme.Colors.hiVis : Theme.Colors.manila.opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.Colors.ink, lineWidth: 1.5))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Wind")
        .accessibilityValue(gusting ? "Gust blowing" : warning ? "Gust coming" : "Calm")
        .accessibilityIdentifier(AccessibilityID.Game.wind)
    }

    private var nextModule: some View {
        HStack(spacing: 6) {
            ArtImage(hud.shift.badgeArt)
                .frame(width: 34, height: 34)
                .accessibilityIdentifier(AccessibilityID.Game.shift)
                .accessibilityLabel("Site shift: \(hud.shift.title)")
                .accessibilityHidden(false)
            VStack(alignment: .leading, spacing: 0) {
                Text("NEXT")
                    .font(.display(10))
                    .foregroundStyle(Theme.Colors.inkSoft)
                Text(hud.nextKind.title)
                    .font(.display(13))
                    .foregroundStyle(Theme.Colors.ink)
                    .lineLimit(1)
            }
            ArtImage(hud.nextKind.iconArt)
                .frame(width: 30, height: 30)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.Colors.manila.opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.Colors.ink, lineWidth: 1.5))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Next module: \(hud.nextKind.title). Shift: \(hud.shift.title)")
        .accessibilityIdentifier(AccessibilityID.Game.next)
    }

    @ViewBuilder
    private var calloutView: some View {
        if let callout {
            Text(callout.text)
                .font(.display(19, relativeTo: .headline))
                .foregroundStyle(callout.style == .danger ? .white : Theme.Colors.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color(for: callout.style))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.Colors.ink, lineWidth: 2))
                }
                .rotationEffect(.degrees(-1.5))
                .id(callout.id)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
                .accessibilityIdentifier(AccessibilityID.Game.callout)
                .padding(.horizontal, 60)
        }
    }

    private func color(for style: GameViewModel.Callout.Style) -> Color {
        switch style {
        case .great: Theme.Colors.hiVis
        case .good: Theme.Colors.manila
        case .warning: Color(red: 0.98, green: 0.62, blue: 0.25)
        case .danger: Theme.Colors.danger
        }
    }

    // MARK: - Height tape

    private var heightTape: some View {
        let target = max(bestFloors, 10)
        let fraction = min(Double(hud.floors) / Double(target), 1)
        return ZStack(alignment: .bottom) {
            ArtImage("tape_measure")
                .frame(width: 18, height: 220)
            Capsule()
                .fill(Theme.Colors.danger)
                .frame(width: 26, height: 5)
                .offset(y: -CGFloat(fraction) * 214)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: fraction)
        }
        .overlay(alignment: .top) {
            Text(bestFloors > 0 ? "BEST\n\(bestFloors)" : "GOAL\n10")
                .font(.display(10))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Colors.ink)
                .fixedSize()
                .padding(3)
                .background(RoundedRectangle(cornerRadius: 3).fill(Theme.Colors.manila))
                .offset(y: -30)
        }
        .padding(.trailing, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Height toward best")
        .accessibilityValue("\(hud.floors) of \(target) floors")
    }

    // MARK: - Bottom

    private var bottomBar: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 2) {
                    ForEach(0..<hud.maxHardHats, id: \.self) { index in
                        ArtImage(index < hud.hardHats ? "hard_hat" : "hard_hat_empty")
                            .frame(width: 40, height: 32)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Hard hats")
                .accessibilityValue("\(hud.hardHats) of \(hud.maxHardHats)")
                .accessibilityIdentifier(AccessibilityID.Game.hats)

                swayMeter
            }
            Spacer()
            rushGauge
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            BeamPlate()
                .opacity(0.92)
                .padding(.horizontal, -6)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var swayMeter: some View {
        HStack(spacing: 6) {
            Text("SWAY")
                .font(.display(12))
                .foregroundStyle(Theme.Colors.concreteLight)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.6))
                    Capsule()
                        .fill(hud.swayFraction > 0.75 ? Theme.Colors.danger : hud.swayFraction > 0.45 ? Theme.Colors.hiVis : Theme.Colors.safetyGreen)
                        .frame(width: max(6, proxy.size.width * hud.swayFraction))
                }
            }
            .frame(width: 110, height: 10)
            .animation(.easeOut(duration: 0.2), value: hud.swayFraction)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tower sway")
        .accessibilityValue(Formatters.percent(hud.swayFraction))
        .accessibilityIdentifier(AccessibilityID.Game.sway)
    }

    private var rushGauge: some View {
        let fraction = Double(hud.rush) / Double(max(hud.rushCap, 1))
        return HStack(spacing: 6) {
            Text(Formatters.multiplier(hud.rushMultiplier))
                .font(.display(18))
                .foregroundStyle(hud.rush > 0 ? Theme.Colors.hiVis : Theme.Colors.concrete)
                .monospacedDigit()
            ZStack {
                ArtImage("gauge_rush")
                ArtImage("gauge_needle")
                    .rotationEffect(.degrees(-120 + 240 * fraction))
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: fraction)
            }
            .frame(width: 66, height: 66)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rush multiplier")
        .accessibilityValue(Formatters.multiplier(hud.rushMultiplier))
        .accessibilityIdentifier(AccessibilityID.Game.rush)
    }

    // MARK: - Shift banner

    @ViewBuilder
    private var banner: some View {
        if let shift = shiftBanner {
            VStack(spacing: 6) {
                ArtImage(shift.badgeArt).frame(width: 64, height: 64)
                Text("NEW SHIFT")
                    .font(.display(13))
                    .letterSpacing(2)
                    .foregroundStyle(Theme.Colors.inkSoft)
                Text(shift.title)
                    .font(.display(28, relativeTo: .title))
                    .foregroundStyle(Theme.Colors.ink)
                Text(shift.detail)
                    .font(.body(15, bold: true))
                    .foregroundStyle(Theme.Colors.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: 300)
            .background { ManilaBackground() }
            .overlay(alignment: .top) {
                HazardStripes()
                    .frame(height: 10)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(.horizontal, 12)
                    .offset(y: -5)
            }
            .transition(.scale(scale: 0.7).combined(with: .opacity))
            .allowsHitTesting(false)
            .accessibilityElement(children: .combine)
        }
    }
}
