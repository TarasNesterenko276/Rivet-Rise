import Foundation

/// Accessibility identifiers shared with the UI tests (duplicated there as plain strings).
enum AccessibilityID {
    enum Site {
        static let screen = "site.screen"
        static let clockIn = "site.clockIn"
        static let bolts = "site.bolts"
        static let best = "site.best"
        static let foreman = "site.foreman"
        static func floorButton(_ floor: SiteFloor) -> String { "pendant.\(floor.rawValue)" }
    }

    enum Hoist {
        static let ground = "hoist.ground"
    }

    enum Yard {
        static let screen = "yard.screen"
        static func hoist(_ kind: UpgradeKind) -> String { "yard.hoist.\(kind.rawValue)" }
        static func level(_ kind: UpgradeKind) -> String { "yard.level.\(kind.rawValue)" }
    }

    enum Lockers {
        static let screen = "lockers.screen"
        static let action = "lockers.action"
        static let selectedName = "lockers.selectedName"
        static func locker(_ foreman: Foreman) -> String { "lockers.foreman.\(foreman.rawValue)" }
    }

    enum Log {
        static let screen = "log.screen"
        static let empty = "log.empty"
        static let stats = "log.stats"
        static let stickers = "log.stickers"
        static let bestScore = "log.bestScore"
    }

    enum Manual {
        static let screen = "manual.screen"
        static let next = "manual.next"
        static let done = "manual.done"
    }

    enum Office {
        static let screen = "office.screen"
        static let haptics = "office.haptics"
        static let sound = "office.sound"
        static let manual = "office.manual"
        static let reset = "office.reset"
        static let resetConfirm = "office.resetConfirm"
    }

    enum Game {
        static let screen = "game.screen"
        static let start = "game.start"
        static let leave = "game.leave"
        static let countdown = "game.countdown"
        static let pause = "game.pause"
        static let resume = "game.resume"
        static let restart = "game.restart"
        static let quit = "game.quit"
        static let envelope = "game.envelope"
        static let again = "game.again"
        static let toSite = "game.toSite"
        static let toYard = "game.toYard"
        static let tapArea = "game.tapArea"
        static let score = "hud.score"
        static let floors = "hud.floors"
        static let hats = "hud.hats"
        static let sway = "hud.sway"
        static let rush = "hud.rush"
        static let wind = "hud.wind"
        static let next = "hud.next"
        static let callout = "hud.callout"
        static let shift = "hud.shift"
    }

    enum Board {
        static let screen = "board.screen"
        static let tabs = "board.tabs"
        static let web = "board.web"
        static let orders = "board.orders"
        static let league = "board.league"
        static func order(_ id: String) -> String { "board.order.\(id)" }
    }

    static let toast = "toast"
}
