import SwiftUI

/// The main call to action: a chunky hi-vis plate with a hazard-striped lip that sinks when pressed.
struct HiVisButtonStyle: ButtonStyle {
    var tint: Color = Theme.Colors.hiVis
    var isProminent = true

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.display(isProminent ? 24 : 18, relativeTo: .headline))
            .letterSpacing(1.4)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Colors.ink)
            .padding(.vertical, isProminent ? 15 : 10)
            .padding(.horizontal, 22)
            .frame(minHeight: Theme.Metrics.minimumTap)
            // The plate sits on its own ink "lip"; the first background is drawn nearest the label.
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [tint.blended(with: .white, by: 0.25), tint, tint.blended(with: .black, by: 0.18)], startPoint: .top, endPoint: .bottom))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Theme.Colors.ink, lineWidth: 2)
                    }
            }
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.Colors.ink)
                    .offset(y: pressed ? 1 : 5)
            }
            .offset(y: pressed ? 4 : 0)
            .animation(.spring(response: 0.16, dampingFraction: 0.85), value: pressed)
    }
}

/// A quieter button printed on manila: ink text inside an ink outline.
struct FormButtonStyle: ButtonStyle {
    var tint: Color = Theme.Colors.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body(17, relativeTo: .headline, bold: true))
            .foregroundStyle(tint)
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .frame(minHeight: Theme.Metrics.minimumTap)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.Colors.manila.opacity(configuration.isPressed ? 0.7 : 1))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(tint, lineWidth: 2)
                    }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.85), value: configuration.isPressed)
    }
}

/// Scales any tapped diegetic object down slightly while pressed.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .brightness(configuration.isPressed ? 0.08 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// A round pendant push-button: a coloured cap in a black rubber boot.
struct PendantButtonStyle: ButtonStyle {
    var cap: Color = Theme.Colors.hiVis
    var diameter: CGFloat = 58

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .frame(width: diameter, height: diameter)
            .background {
                Circle()
                    .fill(RadialGradient(colors: [cap.blended(with: .white, by: 0.35), cap, cap.blended(with: .black, by: 0.25)], center: .init(x: 0.35, y: 0.3), startRadius: 2, endRadius: diameter * 0.7))
                    .overlay(Circle().strokeBorder(Theme.Colors.ink, lineWidth: 2))
                    .offset(y: pressed ? 3 : 0)
            }
            .offset(y: pressed ? 3 : 0)
            .background {
                Circle()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: diameter + 10, height: diameter + 10)
                    .offset(y: 4)
            }
            .animation(.spring(response: 0.15, dampingFraction: 0.85), value: pressed)
    }
}
