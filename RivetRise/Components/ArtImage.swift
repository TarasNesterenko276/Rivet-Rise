import SwiftUI

/// A generated artwork from the asset catalog, scaled to fit its frame.
struct ArtImage: View {
    let name: String

    init(_ name: String) {
        self.name = name
    }

    var body: some View {
        Image(name)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .accessibilityHidden(true)
    }
}

/// The 9-slice riveted steel plate behind HUD numbers and headers.
struct BeamPlate: View {
    var body: some View {
        Image("plate_beam")
            .resizable(capInsets: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12), resizingMode: .stretch)
            .accessibilityHidden(true)
    }
}

/// The 9-slice hi-vis panel used for tags and prominent badges.
struct HiVisPlate: View {
    var body: some View {
        Image("plate_hivis")
            .resizable(capInsets: EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14), resizingMode: .stretch)
            .accessibilityHidden(true)
    }
}

/// Manila form paper with a thin ink edge, used for anything long the player reads.
struct ManilaBackground: View {
    var cornerRadius: CGFloat = Theme.Metrics.corner

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(ImagePaint(image: Image("tex_manila"), scale: 1))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.Colors.ink.opacity(0.55), lineWidth: 1.5)
            }
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }
}

/// A full-bleed tiled texture that never widens the layout.
struct TiledBackground: View {
    let texture: String
    var tint: Color = .clear

    var body: some View {
        Rectangle()
            .fill(ImagePaint(image: Image(texture), scale: 1))
            .overlay(tint)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

/// Bolt balance on a steel plate.
struct BoltBadge: View {
    let amount: Int

    var body: some View {
        HStack(spacing: 6) {
            ArtImage("icon_bolt")
                .frame(width: 24, height: 24)
            Text(Formatters.integer(amount))
                .font(.display(20, relativeTo: .headline))
                .foregroundStyle(Theme.Colors.hiVis)
                .monospacedDigit()
                .numericTransition()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background { BeamPlate() }
        .animation(.easeOut(duration: 0.25), value: amount)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bolts")
        .accessibilityValue(Formatters.integer(amount))
    }
}

/// A row of small LED-style segments, e.g. upgrade levels on a job tag.
struct LevelStripes: View {
    let level: Int
    let maxLevel: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<maxLevel, id: \.self) { index in
                Rectangle()
                    .fill(index < level ? Theme.Colors.hiVis : Theme.Colors.ink.opacity(0.18))
                    .overlay(Rectangle().strokeBorder(Theme.Colors.ink, lineWidth: 1))
                    .frame(width: 16, height: 8)
                    .rotationEffect(.degrees(-8))
            }
        }
        .accessibilityHidden(true)
    }
}
