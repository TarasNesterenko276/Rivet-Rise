import SwiftUI

/// The hoist cab every section rides up in: an LED floor indicator with a "Ground" button
/// pinned to the top, the section's own background, and its content underneath.
struct HoistShell<Content: View, Backdrop: View>: View {
    let floor: SiteFloor
    let onGround: () -> Void
    @ViewBuilder let backdrop: () -> Backdrop
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            indicator
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background { backdrop().ignoresSafeArea() }
    }

    private var indicator: some View {
        HStack(spacing: 12) {
            Button(action: onGround) {
                HStack(spacing: 6) {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 13, weight: .black))
                    Text("Ground")
                        .font(.display(17, relativeTo: .headline))
                        .textCase(.uppercase)
                }
                .foregroundStyle(Theme.Colors.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: Theme.Metrics.minimumTap)
                .background { HiVisPlate() }
            }
            .buttonStyle(PressableStyle())
            .accessibilityIdentifier(AccessibilityID.Hoist.ground)
            .accessibilityLabel("Back to the site")

            Spacer(minLength: 4)

            Text(floor.title)
                .font(.display(22, relativeTo: .title2))
                .textCase(.uppercase)
                .letterSpacing(1)
                .foregroundStyle(Theme.Colors.concreteLight)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)

            // LED floor number, like the display inside a construction hoist.
            Text("\(floor.level)")
                .font(.system(size: 26, weight: .heavy, design: .monospaced))
                .foregroundStyle(Theme.Colors.led)
                .shadow(color: Theme.Colors.led.opacity(0.8), radius: 6)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.black))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.Colors.graphite, lineWidth: 2))
                .accessibilityLabel("Floor \(floor.level)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            BeamPlate()
                .padding(.horizontal, -4)
                .ignoresSafeArea(edges: .top)
        }
    }
}
