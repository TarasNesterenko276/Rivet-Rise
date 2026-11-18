import SwiftUI
import WebKit

/// Hosts the bundled `top_players.html` template in a `WKWebView`.
/// Native → web: the board JSON is passed to `window.RivetBoard.render` once the page reports "ready"
/// and again whenever `board` changes. Web → native: reward slot taps arrive through `onSlotTap`.
struct BoardWebView: UIViewRepresentable {
    let board: WeeklyBoard?
    let onSlotTap: (String) -> Void

    static let messageHandlerName = "rivetBoard"

    func makeCoordinator() -> Coordinator { Coordinator(onSlotTap: onSlotTap) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: Self.messageHandlerName)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        context.coordinator.webView = webView
        if let url = Bundle.main.url(forResource: "top_players", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onSlotTap = onSlotTap
        context.coordinator.show(board)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: messageHandlerName)
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        weak var webView: WKWebView?
        var onSlotTap: (String) -> Void
        private var isReady = false
        private var pending: WeeklyBoard?
        private var rendered: WeeklyBoard?

        init(onSlotTap: @escaping (String) -> Void) {
            self.onSlotTap = onSlotTap
        }

        func show(_ board: WeeklyBoard?) {
            pending = board
            flush()
        }

        private func flush() {
            guard isReady, let board = pending, board != rendered, let webView else { return }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            guard let data = try? encoder.encode(board), let json = String(data: data, encoding: .utf8) else { return }
            rendered = board
            webView.evaluateJavaScript("window.RivetBoard.render(\(json));")
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
            switch type {
            case "ready":
                isReady = true
                rendered = nil
                flush()
            case "slot":
                if let id = body["id"] as? String { onSlotTap(id) }
            default:
                break
            }
        }
    }
}
