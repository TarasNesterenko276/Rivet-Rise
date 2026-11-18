import SwiftUI

/// Settings as the site office breaker panel: sound and haptics breakers, the manual on the
/// shelf, and a guarded red "demolish" switch that resets progress.
struct SiteOfficeView: View {
    @StateObject private var viewModel: SiteOfficeViewModel
    let onShowManual: () -> Void
    let onGround: () -> Void

    init(viewModel: SiteOfficeViewModel, onShowManual: @escaping () -> Void, onGround: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onShowManual = onShowManual
        self.onGround = onGround
    }

    var body: some View {
        HoistShell(floor: .office, onGround: onGround) {
            TiledBackground(texture: "tex_concrete", tint: Theme.Colors.steel.opacity(0.25))
        } content: {
            ScrollView {
                VStack(spacing: 16) {
                    breakerPanel
                    manualShelf
                    demolition
                    Text("Rivet Rise \(viewModel.appVersion) · Plays fully offline · No ads, no purchases")
                        .font(.body(13, relativeTo: .caption))
                        .foregroundStyle(Theme.Colors.concreteLight)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(16)
                .frame(maxWidth: Theme.Metrics.maxContentWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .confirmationDialog("Reset all progress?", isPresented: $viewModel.isConfirmingReset, titleVisibility: .visible) {
            Button("Demolish everything", role: .destructive, action: viewModel.confirmReset)
                .accessibilityIdentifier(AccessibilityID.Office.resetConfirm)
            Button("Keep my site", role: .cancel) {}
        } message: {
            Text("Bolts, upgrades, hired foremen and every logged shift will be gone. This cannot be undone.")
        }
        .toast(message: $viewModel.toastMessage, isError: viewModel.toastIsError)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Office.screen)
    }

    // MARK: - Breaker panel

    private var breakerPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BREAKER PANEL")
                .font(.display(15))
                .letterSpacing(2)
                .foregroundStyle(Theme.Colors.hiVis)
            breaker(title: "Sound", detail: "Crane creaks, rivet hits, wind and site ambience.", isOn: $viewModel.soundEnabled, id: AccessibilityID.Office.sound)
            breaker(title: "Haptics", detail: "Feel every landing, rivet and collapse.", isOn: $viewModel.hapticsEnabled, id: AccessibilityID.Office.haptics)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(colors: [Theme.Colors.graphite, Theme.Colors.asphalt], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.Colors.ink, lineWidth: 2))
                .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
        }
    }

    private func breaker(title: String, detail: String, isOn: Binding<Bool>, id: String) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.display(19, relativeTo: .headline))
                    .foregroundStyle(Theme.Colors.ink)
                Text(detail)
                    .font(.body(14))
                    .foregroundStyle(Theme.Colors.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(BreakerToggleStyle())
        .padding(12)
        .background { ManilaBackground(cornerRadius: 6) }
        .accessibilityIdentifier(id)
    }

    // MARK: - Manual and reset

    private var manualShelf: some View {
        Button(action: onShowManual) {
            HStack(spacing: 12) {
                ArtImage("pict_manual").frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Read the site manual")
                        .font(.display(19, relativeTo: .headline))
                    Text("Every rule of the crane, one illustrated page each.")
                        .font(.body(14))
                        .foregroundStyle(Theme.Colors.inkSoft)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.body.bold())
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Theme.Colors.ink)
            .padding(12)
            .background { ManilaBackground(cornerRadius: 6) }
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier(AccessibilityID.Office.manual)
    }

    private var demolition: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Demolition")
                    .font(.display(19, relativeTo: .headline))
                    .foregroundStyle(Theme.Colors.danger)
                Spacer()
                Rectangle()
                    .fill(.clear)
                    .frame(width: 60, height: 10)
                    .background(HazardStripes())
                    .accessibilityHidden(true)
            }
            Text("Clears the whole site: bolts, upgrades, foremen and every logged shift.")
                .font(.body(14))
                .foregroundStyle(Theme.Colors.ink)
                .fixedSize(horizontal: false, vertical: true)
            Button(role: .destructive, action: viewModel.requestReset) {
                Text("Reset progress")
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(HiVisButtonStyle(tint: Theme.Colors.danger, isProminent: false))
            .accessibilityIdentifier(AccessibilityID.Office.reset)
        }
        .padding(12)
        .background { ManilaBackground(cornerRadius: 6) }
    }
}

/// A chunky circuit-breaker lever: down and grey when off, up and hi-vis when on.
struct BreakerToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 14) {
                configuration.label
                Spacer(minLength: 8)
                ZStack(alignment: configuration.isOn ? .top : .bottom) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.Colors.asphalt)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.Colors.ink, lineWidth: 2))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(configuration.isOn ? Theme.Colors.hiVis : Theme.Colors.concrete)
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.Colors.ink, lineWidth: 2))
                        .frame(height: 26)
                        .padding(4)
                }
                .frame(width: 40, height: 62)
                .overlay(alignment: .trailing) {
                    Text(configuration.isOn ? "ON" : "OFF")
                        .font(.display(12))
                        .foregroundStyle(configuration.isOn ? Theme.Colors.safetyGreen : Theme.Colors.inkSoft)
                        .fixedSize()
                        .offset(x: 30)
                }
                .padding(.trailing, 26)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}

/// Black and yellow warning stripes.
struct HazardStripes: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.Colors.hiVis))
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + 6, y: size.height))
                path.addLine(to: CGPoint(x: x + 6 + size.height, y: 0))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                path.closeSubpath()
                context.fill(path, with: .color(Theme.Colors.ink))
                x += 12
            }
        }
        .accessibilityHidden(true)
    }
}
