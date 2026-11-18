import Foundation
import Combine

/// Pages through the site manual. Before the first shift, finishing it starts the game.
@MainActor
final class ManualViewModel: ObservableObject {
    let pages = ManualPage.all
    @Published var index = 0
    let startsShiftWhenDone: Bool

    private let settings: SettingsStore
    private let onFinish: (_ startShift: Bool) -> Void

    init(settings: SettingsStore, startsShiftWhenDone: Bool, onFinish: @escaping (_ startShift: Bool) -> Void) {
        self.settings = settings
        self.startsShiftWhenDone = startsShiftWhenDone
        self.onFinish = onFinish
    }

    var isLastPage: Bool { index >= pages.count - 1 }
    var doneTitle: String { startsShiftWhenDone ? "Clock in" : "Got it" }

    func next() {
        if isLastPage {
            finish()
        } else {
            index += 1
        }
    }

    func previous() {
        index = max(0, index - 1)
    }

    func finish() {
        settings.hasSeenGuide = true
        onFinish(startsShiftWhenDone)
    }
}
