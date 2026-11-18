import SwiftUI

/// The pre-shift briefing: a job sheet clipped to the crane, with the foreman and the goal.
struct ShiftBriefingOverlay: View {
    let foreman: Foreman
    let shiftNumber: Int
    let bestFloors: Int
    let bestScore: Int
    let onStart: () -> Void
    let onLeave: () -> Void

    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("JOB SHEET · SHIFT \(shiftNumber)")
                        .font(.typed(14, bold: true))
                        .foregroundStyle(Theme.Colors.inkSoft)
                    Spacer()
                    HazardStripes()
                        .frame(width: 54, height: 10)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                HStack(spacing: 12) {
                    ArtImage(foreman.portraitArt)
                        .frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.Colors.ink, lineWidth: 2))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(foreman.name) in the cab")
                            .font(.display(22, relativeTo: .title2))
                            .foregroundStyle(Theme.Colors.ink)
                        Text("\(foreman.perkTitle): \(foreman.perkDetail)")
                            .font(.body(14))
                            .foregroundStyle(Theme.Colors.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    checklist("Tap to drop the module on the tower.")
                    checklist("Tap again when the ring hits the yellow mark to rivet.")
                    checklist("Land while the plumb bob is in the green band.")
                }
                HStack {
                    Text(bestFloors > 0 ? "Beat \(bestFloors) floors · \(Formatters.integer(bestScore)) pts" : "Goal: stand 10 floors")
                        .font(.typed(14, bold: true))
                        .foregroundStyle(Theme.Colors.ink)
                    Spacer()
                }
                HStack(spacing: 12) {
                    Button("Leave", action: onLeave)
                        .buttonStyle(FormButtonStyle())
                        .accessibilityIdentifier(AccessibilityID.Game.leave)
                    Button(action: onStart) {
                        Text("Start shift").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(HiVisButtonStyle())
                    .accessibilityIdentifier(AccessibilityID.Game.start)
                }
            }
            .padding(18)
            .background { ManilaBackground() }
            .frame(maxWidth: 520)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color.black.opacity(0.25).ignoresSafeArea())
    }

    private func checklist(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.square")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.Colors.safetyGreen)
                .accessibilityHidden(true)
            Text(text)
                .font(.typed(14))
                .foregroundStyle(Theme.Colors.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A big stencilled 3-2-1 on a hi-vis plate.
struct CountdownOverlay: View {
    let value: Int

    var body: some View {
        Text("\(value)")
            .font(.display(96))
            .foregroundStyle(Theme.Colors.ink)
            .frame(width: 150, height: 150)
            .background { HiVisPlate() }
            .id(value)
            .transition(.scale(scale: 1.4).combined(with: .opacity))
            .accessibilityLabel("Starting in \(value)")
            .accessibilityIdentifier(AccessibilityID.Game.countdown)
    }
}

/// The pause menu: a "work stopped" sign.
struct PauseOverlay: View {
    let hud: GameHUDState
    let onResume: () -> Void
    let onRestart: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                HazardStripes()
                    .frame(height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                Text("Work stopped")
                    .font(.display(32, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.Colors.ink)
                Text("\(hud.floors) floors · \(Formatters.integer(hud.score)) points · \(hud.hardHats) hard hats left")
                    .font(.typed(15, bold: true))
                    .foregroundStyle(Theme.Colors.inkSoft)
                    .multilineTextAlignment(.center)
                Button(action: onResume) {
                    Text("Back to work").frame(maxWidth: .infinity)
                }
                .buttonStyle(HiVisButtonStyle())
                .accessibilityIdentifier(AccessibilityID.Game.resume)
                HStack(spacing: 12) {
                    Button(action: onRestart) {
                        Text("Restart").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FormButtonStyle())
                    .accessibilityIdentifier(AccessibilityID.Game.restart)
                    Button(action: onQuit) {
                        Text("Clock out").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FormButtonStyle(tint: Theme.Colors.danger))
                    .accessibilityIdentifier(AccessibilityID.Game.quit)
                }
                Text("Clocking out mid-shift pays nothing.")
                    .font(.body(13))
                    .foregroundStyle(Theme.Colors.inkSoft)
                HazardStripes()
                    .frame(height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .padding(20)
            .background { ManilaBackground() }
            .frame(maxWidth: 400)
            .padding(24)
        }
    }
}

/// End of shift: a kraft pay envelope with the shift typed on it and a topping-out photo.
struct PayEnvelopeOverlay: View {
    let outcome: RunOutcome
    let foreman: Foreman
    let onAgain: () -> Void
    let onYard: () -> Void
    let onSite: () -> Void

    @State private var revealed = false

    private var summary: RunSummary { outcome.summary }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    envelope
                    buttons
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 24)
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.2)) { revealed = true }
        }
    }

    private var envelope: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PAY ENVELOPE")
                        .font(.typed(20, bold: true))
                        .foregroundStyle(Theme.Colors.ink)
                    Text("Site 18 · Foreman \(foreman.name) · \(Formatters.duration(summary.duration))")
                        .font(.typed(13))
                        .foregroundStyle(Theme.Colors.ink.opacity(0.8))
                }
                Spacer()
            }
            .padding(.top, 70)

            VStack(spacing: 4) {
                row("Tallest tower", "\(summary.floors) floors", highlight: outcome.isNewBestFloors)
                row("Perfect drops", "\(summary.perfects)")
                row("Rivets driven", "\(summary.rivets)")
                row("Districts", "\(summary.districts)")
                row("Penthouses", "\(summary.penthouses)")
                row("Cable catches", "\(summary.clutches)")
                row("Collapses", "\(summary.collapses)")
                row("Best rush", "\(summary.bestRush)")
                Rectangle().fill(Theme.Colors.ink).frame(height: 1.5).padding(.vertical, 2)
                row("Points", Formatters.integer(summary.score), highlight: outcome.isNewBestScore)
            }
            .padding(12)
            .background { ManilaBackground(cornerRadius: 3) }

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PAID")
                        .font(.typed(13, bold: true))
                        .foregroundStyle(Theme.Colors.ink)
                    HStack(spacing: 6) {
                        ArtImage("icon_bolt").frame(width: 30, height: 30)
                        Text("+\(Formatters.integer(summary.bolts))")
                            .font(.display(34, relativeTo: .largeTitle))
                            .foregroundStyle(Theme.Colors.ink)
                            .monospacedDigit()
                    }
                    Text("Balance \(Formatters.integer(outcome.totalBolts)) bolts")
                        .font(.typed(13))
                        .foregroundStyle(Theme.Colors.ink.opacity(0.85))
                }
                Spacer()
                if outcome.isNewBestScore || outcome.isNewBestFloors {
                    Text("NEW\nRECORD")
                        .font(.display(20))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.Colors.danger)
                        .padding(8)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.Colors.danger, lineWidth: 3))
                        .rotationEffect(.degrees(revealed ? -12 : -40))
                        .scaleEffect(revealed ? 1 : 2.2)
                        .opacity(revealed ? 0.9 : 0)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background {
            // The flap stays intact; only the plain kraft body below it stretches.
            Image("envelope")
                .resizable(capInsets: EdgeInsets(top: 112, leading: 24, bottom: 24, trailing: 24), resizingMode: .stretch)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .topTrailing) {
            ArtImage("photo_topping")
                .frame(width: 120)
                .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                .rotationEffect(.degrees(revealed ? 7 : 25))
                .offset(x: 6, y: revealed ? -10 : -60)
                .opacity(revealed ? 1 : 0)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Game.envelope)
    }

    private func row(_ label: String, _ value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(label)
            Spacer()
            if highlight {
                Image(systemName: "star.fill")
                    .foregroundStyle(Theme.Colors.danger)
                    .accessibilityLabel("New record")
            }
            Text(value).monospacedDigit()
        }
        .font(.typed(15))
        .foregroundStyle(Theme.Colors.ink)
        .accessibilityElement(children: .combine)
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            Button(action: onAgain) {
                Text("Clock in again").frame(maxWidth: .infinity)
            }
            .buttonStyle(HiVisButtonStyle())
            .accessibilityIdentifier(AccessibilityID.Game.again)
            HStack(spacing: 12) {
                Button(action: onYard) {
                    Text("Rigging Yard").frame(maxWidth: .infinity)
                }
                .buttonStyle(FormButtonStyle())
                .accessibilityIdentifier(AccessibilityID.Game.toYard)
                Button(action: onSite) {
                    Text("To the site").frame(maxWidth: .infinity)
                }
                .buttonStyle(FormButtonStyle())
                .accessibilityIdentifier(AccessibilityID.Game.toSite)
            }
        }
    }
}
