import AdjustSdk
import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

final class IntegrationAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate, AdjustDelegate {
    static weak var shared: IntegrationAppDelegate?
    private var lastHandledURL: URL?
    @MainActor private var apnsRegistrationFailed = false
    private static let fcmTokenKey = "rivet.fcm_token"

    override init() {
        super.init()
        Self.shared = self
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
        Messaging.messaging().isAutoInitEnabled = false
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        if let url = Bundle.main.url(forResource: "OnlineConfiguration", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let token = config["adjustAppToken"] as? String, !token.isEmpty {
            let adjust = ADJConfig(appToken: token, environment: ADJEnvironmentProduction)
            adjust?.delegate = self
            Adjust.initSdk(adjust)
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let messaging = Messaging.messaging()
        messaging.apnsToken = deviceToken
        messaging.token { token, error in
            Self.storeFCMToken(token)
            if let error = error as NSError? {
                NSLog("Firebase token fetch failed (%@ %ld)", error.domain, error.code)
            }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        apnsRegistrationFailed = true
        let failure = error as NSError
        NSLog("APNs registration failed (%@ %ld)", failure.domain, failure.code)
    }

    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        handleIncomingURL(url)
        return true
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if let url = userActivity.webpageURL {
            handleIncomingURL(url)
            return true
        }
        return false
    }

    func handleIncomingURL(_ url: URL) {
        guard lastHandledURL != url else { return }
        lastHandledURL = url
        UserDefaults.standard.set(url.absoluteString, forKey: "rivet.pending_deeplink")
        if let deeplink = ADJDeeplink(deeplink: url) {
            Adjust.processDeeplink(deeplink)
        }
    }

    func adjustDeferredDeeplinkReceived(_ deeplink: URL?) -> Bool {
        if let deeplink {
            UserDefaults.standard.set(deeplink.absoluteString, forKey: "rivet.pending_deeplink")
        }
        return false
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Self.storeFCMToken(fcmToken)
    }

    private static func storeFCMToken(_ token: String?) {
        guard let token, !token.isEmpty else { return }
        UserDefaults.standard.set(token, forKey: fcmTokenKey)
        NSLog("Firebase registration token received (length: %ld)", token.count)
    }

    @MainActor
    func preparePushToken() async -> String {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        apnsRegistrationFailed = false
        Messaging.messaging().isAutoInitEnabled = true
        UIApplication.shared.registerForRemoteNotifications()

        // Registration returns immediately. Give the APNs and Firebase callbacks time
        // on a fresh install, while letting a slow or unavailable service leave Splash.
        let deadline = ProcessInfo.processInfo.systemUptime + 10
        while ProcessInfo.processInfo.systemUptime < deadline {
            if let token = UserDefaults.standard.string(forKey: Self.fcmTokenKey), !token.isEmpty {
                return token
            }
            guard !apnsRegistrationFailed else { return "" }
            do { try await Task.sleep(nanoseconds: 100_000_000) } catch { return "" }
        }
        let token = UserDefaults.standard.string(forKey: Self.fcmTokenKey) ?? ""
        if token.isEmpty { NSLog("Launch continued before Firebase supplied a push token") }
        return token
    }
}
