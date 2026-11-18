import Foundation

/// Formatting helpers for numbers and durations shown in the interface.
enum Formatters {
    /// Formats a duration in seconds as `m:ss`.
    static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Formats a score or bolt amount with grouping separators.
    static func integer(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    /// Formats a tower height in metres (a floor is 3.5 m), e.g. "84 m".
    static func metres(floors: Int) -> String {
        "\(Int((Double(floors) * 3.5).rounded())) m"
    }

    /// Formats a percentage from a fraction, e.g. "86%".
    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    /// Formats seconds as whole milliseconds, e.g. "170 ms".
    static func milliseconds(_ seconds: Double) -> String {
        "\(Int((seconds * 1000).rounded())) ms"
    }

    /// Formats a multiplier, e.g. "x1.4".
    static func multiplier(_ value: Double) -> String {
        "x" + twoDecimalsTrimmed(value)
    }

    /// Up to two decimals, trimming trailing zeros ("1.25", "1.5", "2"). Locale-independent.
    static func twoDecimalsTrimmed(_ value: Double) -> String {
        var text = String(format: "%.2f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    /// Formats a date for the timesheet.
    static func shiftDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }

    static func shiftTime(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }
}
