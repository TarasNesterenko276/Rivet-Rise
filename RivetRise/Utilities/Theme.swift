import SwiftUI

/// Visual language of Rivet Rise: hi-vis safety yellow over asphalt and concrete,
/// a dawn sky, and manila paper for anything the player has to read.
enum Theme {
    enum Colors {
        static let hiVis = Color(red: 0.96, green: 0.76, blue: 0.11)
        static let hiVisDeep = Color(red: 0.79, green: 0.58, blue: 0.04)
        static let asphalt = Color(red: 0.14, green: 0.15, blue: 0.17)
        static let graphite = Color(red: 0.20, green: 0.22, blue: 0.25)
        static let concrete = Color(red: 0.73, green: 0.71, blue: 0.68)
        static let concreteLight = Color(red: 0.87, green: 0.86, blue: 0.83)
        static let rust = Color(red: 0.77, green: 0.33, blue: 0.17)
        static let steel = Color(red: 0.30, green: 0.42, blue: 0.53)
        static let skyTeal = Color(red: 0.25, green: 0.65, blue: 0.71)
        static let skyPeach = Color(red: 0.96, green: 0.77, blue: 0.60)
        static let manila = Color(red: 0.92, green: 0.86, blue: 0.72)
        static let manilaShade = Color(red: 0.83, green: 0.74, blue: 0.56)
        static let kraft = Color(red: 0.78, green: 0.61, blue: 0.38)
        /// Text on manila and yellow (contrast ≥ 11:1).
        static let ink = Color(red: 0.12, green: 0.11, blue: 0.09)
        static let inkSoft = Color(red: 0.33, green: 0.29, blue: 0.23)
        static let safetyGreen = Color(red: 0.16, green: 0.50, blue: 0.27)
        static let danger = Color(red: 0.75, green: 0.18, blue: 0.12)
        static let lamp = Color(red: 1.0, green: 0.88, blue: 0.55)
        static let led = Color(red: 1.0, green: 0.62, blue: 0.20)
    }

    enum Metrics {
        static let maxContentWidth: CGFloat = 600
        static let corner: CGFloat = 12
        static let minimumTap: CGFloat = 44
    }
}

extension Font {
    /// Condensed heavy face for titles, numbers and buttons (construction signage).
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom("HelveticaNeue-CondensedBlack", size: size, relativeTo: style)
    }

    /// Body face for descriptions and labels.
    static func body(_ size: CGFloat, relativeTo style: Font.TextStyle = .body, bold: Bool = false) -> Font {
        .custom(bold ? "TrebuchetMS-Bold" : "TrebuchetMS", size: size, relativeTo: style)
    }

    /// Typewriter face for forms: the timesheet, pay envelope and job tags.
    static func typed(_ size: CGFloat, relativeTo style: Font.TextStyle = .body, bold: Bool = false) -> Font {
        .custom(bold ? "AmericanTypewriter-Bold" : "AmericanTypewriter", size: size, relativeTo: style)
    }
}
