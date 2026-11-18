import SwiftUI
import UIKit

// Rivet Rise supports iOS 15. These helpers use newer SwiftUI APIs when the system has them
// and fall back to an equivalent (or simply skip a cosmetic effect) on older versions.

extension Color {
    /// Mixes two colours in sRGB, like `Color.mix(with:by:)` from iOS 18.
    func blended(with other: Color, by fraction: Double) -> Color {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        UIColor(self).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        UIColor(other).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = CGFloat(min(max(fraction, 0), 1))
        return Color(.sRGB, red: Double(r1 + (r2 - r1) * t), green: Double(g1 + (g2 - g1) * t),
                     blue: Double(b1 + (b2 - b1) * t), opacity: Double(a1 + (a2 - a1) * t))
    }
}

extension View {
    /// Rolling digits for changing numbers (iOS 16+); a plain update before that.
    @ViewBuilder
    func numericTransition() -> some View {
        if #available(iOS 16.0, *) {
            contentTransition(.numericText())
        } else {
            self
        }
    }

    /// Hides the home indicator during a shift (iOS 16+).
    @ViewBuilder
    func hidesSystemOverlays() -> some View {
        if #available(iOS 16.0, *) {
            persistentSystemOverlays(.hidden)
        } else {
            self
        }
    }

    /// A short bottom sheet on iOS 16+; a regular sheet before that.
    @ViewBuilder
    func compactSheetHeight(_ height: CGFloat) -> some View {
        if #available(iOS 16.0, *) {
            presentationDetents([.height(height)])
        } else {
            self
        }
    }

    /// Letter spacing for any view (iOS 16+); text keeps its default spacing before that.
    @ViewBuilder
    func letterSpacing(_ value: CGFloat) -> some View {
        if #available(iOS 16.0, *) {
            tracking(value)
        } else {
            self
        }
    }
}
