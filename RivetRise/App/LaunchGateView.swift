import SwiftUI
import WebKit
import MessageUI

/// Resolves the server launch rule once per cold start. Network failures always open the native game.
struct LaunchGateView: View {
    let dependencies: AppDependencies
    @State private var resolved = false
    @State private var resolving = false
    @State private var remoteURL: URL?

    var body: some View {
        Group {
            if !resolved {
                ZStack {
                    Theme.Colors.asphalt.ignoresSafeArea()
                    VStack(spacing: 18) {
                        Image("hard_hat_big").resizable().scaledToFit().frame(maxWidth: 180)
                        Text("RIVET RISE").font(.display(30)).foregroundStyle(Theme.Colors.concreteLight)
                        ProgressView("Starting…").tint(.white).foregroundStyle(.white)
                    }
                    .padding(24)
                }
                .preferredColorScheme(.dark)
            } else if let remoteURL {
                RemoteLaunchBrowser(url: remoteURL)
                    .background(Color.black.ignoresSafeArea())
            } else {
                RootView(dependencies: dependencies)
            }
        }
        .task {
            guard !resolved, !resolving else { return }
            resolving = true
            defer { resolving = false }
            do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { return }
            let pushToken = dependencies.isUITesting ? "" : await IntegrationAppDelegate.shared?.preparePushToken() ?? ""
            guard !Task.isCancelled else { return }
            if !dependencies.isUITesting, let online = dependencies.onlineLeaderboard,
               let result = try? await online.resolveLaunch(pushToken: pushToken), result.action == "webview",
               let url = result.targetUrl, url.scheme == "https", url.host != nil,
               url.user == nil, url.password == nil {
                remoteURL = url
            }
            guard !Task.isCancelled else { return }
            resolved = true
        }
    }

}

private struct RemoteLaunchBrowser: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> RemoteBrowserController {
        RemoteBrowserController(url: url)
    }
    func updateUIViewController(_ controller: RemoteBrowserController, context: Context) {}
}

@MainActor
private final class RemoteBrowserController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate, MFMailComposeViewControllerDelegate {
    private static let navigationTimeout: UInt64 = 30
    private let initialURL: URL
    private var web: WKWebView!
    private let back = UIButton(type: .system)
    private let forward = UIButton(type: .system)
    private let reload = UIButton(type: .system)
    private let progress = UIProgressView(progressViewStyle: .bar)
    private let errorPanel = UIStackView()
    private let errorLabel = UILabel()
    private var observations: [NSKeyValueObservation] = []
    private var failedURL: URL?
    private var returnHistory: [URL] = []
    private var lastCommittedPageURL: URL?
    private var primaryBlankNavigation = false
    private var hasLoadedInitialPage = false
    private var restoringReturnURL = false
    private var activeNavigation: WKNavigation?
    private var navigationDeadline: Task<Void, Never>?
    private var downloads: [ObjectIdentifier: URL] = [:]
    private var downloadDirectories: [URL] = []

    init(url: URL) {
        initialURL = url; lastCommittedPageURL = url
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        overrideUserInterfaceStyle = .dark
        let settings = WKWebViewConfiguration()
        settings.websiteDataStore = .default()
        settings.defaultWebpagePreferences.allowsContentJavaScript = true
        settings.allowsInlineMediaPlayback = true
        settings.mediaTypesRequiringUserActionForPlayback = []
        web = WKWebView(frame: .zero, configuration: settings)
        web.navigationDelegate = self
        web.uiDelegate = self
        web.allowsBackForwardNavigationGestures = true
        web.allowsLinkPreview = true
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.backgroundColor = .black
        let bar = UIStackView(arrangedSubviews: [back, forward, reload])
        bar.axis = .horizontal
        bar.distribution = .fillEqually
        bar.backgroundColor = .black
        configure(back, symbol: "chevron.left", label: "Back", action: #selector(goBack))
        configure(forward, symbol: "chevron.right", label: "Forward", action: #selector(goForward))
        configure(reload, symbol: "arrow.clockwise", label: "Reload", action: #selector(reloadPage))
        for child in [web!, bar, progress] {
            child.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(child)
        }
        NSLayoutConstraint.activate([
            web.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            web.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            web.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            web.bottomAnchor.constraint(equalTo: bar.topAnchor),
            bar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bar.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
            progress.topAnchor.constraint(equalTo: web.topAnchor),
            progress.leadingAnchor.constraint(equalTo: web.leadingAnchor),
            progress.trailingAnchor.constraint(equalTo: web.trailingAnchor)
        ])
        errorLabel.textAlignment = .center; errorLabel.numberOfLines = 0; errorLabel.textColor = .white
        let retry = UIButton(type: .system)
        retry.setTitle("Try Again", for: .normal); retry.tintColor = .white
        retry.addTarget(self, action: #selector(retryPage), for: .touchUpInside)
        retry.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        errorPanel.axis = .vertical; errorPanel.spacing = 12
        errorPanel.addArrangedSubview(errorLabel); errorPanel.addArrangedSubview(retry)
        errorPanel.translatesAutoresizingMaskIntoConstraints = false; errorPanel.backgroundColor = .black
        errorPanel.isHidden = true; view.addSubview(errorPanel)
        NSLayoutConstraint.activate([
            errorPanel.centerXAnchor.constraint(equalTo: web.centerXAnchor), errorPanel.centerYAnchor.constraint(equalTo: web.centerYAnchor),
            errorPanel.widthAnchor.constraint(lessThanOrEqualTo: web.widthAnchor, constant: -40)
        ])
        observations = [
            web.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] _, _ in Task { @MainActor [weak self] in self?.refreshControls() } },
            web.observe(\.canGoBack, options: [.new]) { [weak self] _, _ in Task { @MainActor [weak self] in self?.refreshControls() } },
            web.observe(\.canGoForward, options: [.new]) { [weak self] _, _ in Task { @MainActor [weak self] in self?.refreshControls() } }
        ]
        refreshControls(); load(initialURL)
    }

    private func configure(_ button: UIButton, symbol: String, label: String, action: Selector) {
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.accessibilityLabel = label
        button.tintColor = .white
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func refreshControls() {
        back.isEnabled = canNavigateBack()
        forward.isEnabled = web.canGoForward
        back.alpha = back.isEnabled ? 1 : 0.35
        forward.alpha = forward.isEnabled ? 1 : 0.35
        progress.progress = Float(web.estimatedProgress)
        progress.isHidden = web.estimatedProgress >= 1
    }

    private func allowsWebNavigation(to url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return false }
        return url.host != nil && url.user == nil && url.password == nil
    }
    private func load(_ url: URL, restoringFromBack: Bool = false) {
        guard allowsWebNavigation(to: url) else { showError("This destination is unavailable."); return }
        errorPanel.isHidden = true; restoringReturnURL = restoringFromBack
        web.load(URLRequest(url: url, timeoutInterval: TimeInterval(Self.navigationTimeout)))
    }
    private func captureReturnPage() {
        let origin = lastCommittedPageURL ?? initialURL
        guard returnHistory.last != origin else { return }
        returnHistory.append(origin)
    }
    private func canNavigateBack() -> Bool { returnHistory.contains { $0 != web.url } || (primaryBlankNavigation && web.url != initialURL) }
    @discardableResult private func navigateBack() -> Bool {
        while let returnURL = returnHistory.popLast() {
            guard returnURL != web.url else { continue }
            primaryBlankNavigation = false
            if let item = web.backForwardList.backList.last(where: { $0.url == returnURL }), web.go(to: item) != nil { return true }
            web.stopLoading(); load(returnURL, restoringFromBack: true); return true
        }
        if primaryBlankNavigation { primaryBlankNavigation = false; web.stopLoading(); load(initialURL, restoringFromBack: true); return true }
        return false
    }
    private func showError(_ message: String) { errorLabel.text = message; errorPanel.isHidden = false; progress.isHidden = true }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        errorPanel.isHidden = true; progress.isHidden = false; clearNavigationDeadline(); activeNavigation = navigation
        navigationDeadline = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: Self.navigationTimeout * 1_000_000_000) } catch { return }
            guard let self else { return }; let url = self.web.url; self.clearNavigationDeadline(); self.web.stopLoading()
            self.handle(URLError(.timedOut, userInfo: url.map { [NSURLErrorFailingURLErrorKey: $0] } ?? [:]))
        }
    }
    private func clearNavigationDeadline() { navigationDeadline?.cancel(); navigationDeadline = nil; activeNavigation = nil }
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { if let url = webView.url, allowsWebNavigation(to: url) { lastCommittedPageURL = url }; refreshControls() }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { if navigation === activeNavigation { clearNavigationDeadline() }; hasLoadedInitialPage = true; restoringReturnURL = false; failedURL = nil; errorPanel.isHidden = true; refreshControls() }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { if navigation === activeNavigation { clearNavigationDeadline() }; handle(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { if navigation === activeNavigation { clearNavigationDeadline() }; handle(error) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { clearNavigationDeadline(); showError("The page stopped responding.") }
    private func handle(_ error: Error) {
        let value = error as NSError
        guard value.code != NSURLErrorCancelled, value.code != 102 else { return }
        restoringReturnURL = false
        if let url = value.userInfo[NSURLErrorFailingURLErrorKey] as? URL, allowsWebNavigation(to: url) { failedURL = url }
        showError("The page could not be loaded. Check your connection and try again.")
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { decisionHandler(.cancel); return }
        let isBlank = url.absoluteString == "about:blank"
        if hasLoadedInitialPage, !restoringReturnURL, !action.shouldPerformDownload,
           (allowsWebNavigation(to: url) || isBlank), action.navigationType != .backForward,
           action.navigationType != .reload,
           (action.targetFrame == nil || action.targetFrame?.isMainFrame == true) {
            captureReturnPage(); refreshControls()
        }
        if allowsWebNavigation(to: url) { if action.shouldPerformDownload { decisionHandler(.download) } else { decisionHandler(.allow) } }
        else if isBlank { if action.targetFrame?.isMainFrame == true { captureReturnPage(); primaryBlankNavigation = true; refreshControls() }; decisionHandler(.allow) }
        else if url.scheme?.lowercased() == "blob" && action.shouldPerformDownload { decisionHandler(.download) }
        else { decisionHandler(.cancel); openExternal(url) }
    }
    private func openExternal(_ url: URL) {
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "intent", let range = url.absoluteString.range(of: "S.browser_fallback_url=") { let value = String(url.absoluteString[range.upperBound...].prefix { $0 != ";" }); if let decoded = value.removingPercentEncoding, let fallback = URL(string: decoded), allowsWebNavigation(to: fallback) { load(fallback) }; return }
        guard !["", "http", "https", "about", "blob", "data", "file", "javascript"].contains(scheme) else { return }
        if scheme == "mailto", presentMailComposer(for: url) { return }
        DispatchQueue.main.async { UIApplication.shared.open(url, options: [:]) }
    }
    private func presentMailComposer(for url: URL) -> Bool {
        guard MFMailComposeViewController.canSendMail(), presentedViewController == nil, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        let composer = MFMailComposeViewController(); composer.mailComposeDelegate = self
        let recipient = components.path.removingPercentEncoding ?? components.path
        let recipients = recipient.split(separator: ",").map(String.init).filter { !$0.isEmpty }; if !recipients.isEmpty { composer.setToRecipients(recipients) }
        for item in components.queryItems ?? [] { switch item.name.lowercased() { case "subject": composer.setSubject(item.value ?? ""); case "body": composer.setMessageBody(item.value ?? "", isHTML: false); case "cc": composer.setCcRecipients((item.value ?? "").split(separator: ",").map(String.init)); case "bcc": composer.setBccRecipients((item.value ?? "").split(separator: ",").map(String.init)); default: break } }
        present(composer, animated: true); return true
    }
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) { controller.dismiss(animated: true) }
    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let url = response.response.url, url.scheme != "blob", url.absoluteString != "about:blank", !allowsWebNavigation(to: url) { decisionHandler(.cancel); openExternal(url); return }
        let disposition = (response.response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Disposition") ?? ""
        let shouldDownload = !response.canShowMIMEType || disposition.lowercased().contains("attachment")
        if shouldDownload && response.isForMainFrame { clearNavigationDeadline() }; decisionHandler(shouldDownload ? .download : .allow)
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = action.request.url else { return nil }; if allowsWebNavigation(to: url) || url.absoluteString == "about:blank" { captureReturnPage(); refreshControls(); webView.load(action.request) } else { openExternal(url) }; return nil
    }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) { let alert = UIAlertController(title: frame.securityOrigin.host, message: message, preferredStyle: .alert); alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() }); guard presentedViewController == nil else { completionHandler(); return }; present(alert, animated: true) }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) { let alert = UIAlertController(title: frame.securityOrigin.host, message: message, preferredStyle: .alert); alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) }); alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) }); guard presentedViewController == nil else { completionHandler(false); return }; present(alert, animated: true) }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) { let alert = UIAlertController(title: frame.securityOrigin.host, message: prompt, preferredStyle: .alert); alert.addTextField { $0.text = defaultText }; alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) }); alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak alert] _ in completionHandler(alert?.textFields?.first?.text) }); guard presentedViewController == nil else { completionHandler(nil); return }; present(alert, animated: true) }
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) { decisionHandler(origin.protocol == "https" ? .prompt : .deny) }
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) { download.delegate = self }
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) { download.delegate = self }
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true); downloadDirectories.append(directory); let name = URL(fileURLWithPath: suggestedFilename).lastPathComponent; let destination = directory.appendingPathComponent(name.isEmpty || name == "." || name == ".." ? "download" : name); downloads[ObjectIdentifier(download)] = destination; completionHandler(destination) }
        catch { completionHandler(nil); showError("The file could not be saved.") }
    }
    func downloadDidFinish(_ download: WKDownload) {
        guard let file = downloads.removeValue(forKey: ObjectIdentifier(download)) else { return }
        let share = UIActivityViewController(activityItems: [file], applicationActivities: nil); share.popoverPresentationController?.sourceView = reload; share.popoverPresentationController?.sourceRect = reload.bounds
        share.completionWithItemsHandler = { _, _, _, _ in try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        guard presentedViewController == nil else { showError("Close the dialog, then download the file again."); return }; present(share, animated: true)
    }
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) { if let file = downloads.removeValue(forKey: ObjectIdentifier(download)) { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }; showError("The download failed. Please try again.") }
    func download(_ download: WKDownload, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, decisionHandler: @escaping (WKDownload.RedirectPolicy) -> Void) { decisionHandler(request.url.map(allowsWebNavigation) == true ? .allow : .cancel) }
    deinit { for directory in downloadDirectories { try? FileManager.default.removeItem(at: directory) } }

    @objc private func goBack() { _ = navigateBack() }
    @objc private func goForward() { guard web.canGoForward else { return }; captureReturnPage(); web.goForward() }
    @objc private func reloadPage() { load(web.url ?? initialURL) }
    @objc private func retryPage() { load(failedURL ?? web.url ?? initialURL) }
}
