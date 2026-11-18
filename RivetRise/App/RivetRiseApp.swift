import SwiftUI

@main
struct RivetRiseApp: App {
    @UIApplicationDelegateAdaptor(IntegrationAppDelegate.self) private var integrationDelegate
    private let bootstrap: Result<AppDependencies, Error>

    init() {
        bootstrap = Result { try AppDependencies() }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch bootstrap {
                case .success(let dependencies):
                    LaunchGateView(dependencies: dependencies)
                case .failure(let error):
                    StartupErrorView(message: error.localizedDescription)
                }
            }
            .onOpenURL { integrationDelegate.handleIncomingURL($0) }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                if let url = activity.webpageURL { integrationDelegate.handleIncomingURL(url) }
            }
        }
    }
}

/// Shown only if the local database cannot be opened, which should never happen in practice.
struct StartupErrorView: View {
    let message: String

    var body: some View {
        ZStack {
            Theme.Colors.asphalt.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.Colors.hiVis)
                    .accessibilityHidden(true)
                Text("The site gate is locked")
                    .font(.display(26))
                    .foregroundStyle(Theme.Colors.concreteLight)
                Text("Rivet Rise could not open its save data. Please restart the app. If the problem persists, reinstalling creates a fresh save.")
                    .font(.body(16))
                    .foregroundStyle(Theme.Colors.concreteLight.opacity(0.9))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.Colors.concreteLight.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .frame(maxWidth: 480)
        }
        .preferredColorScheme(.dark)
    }
}
