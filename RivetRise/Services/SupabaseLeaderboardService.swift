import Foundation
import Security
import UIKit
import AdjustSdk
import WebKit

private struct OnlineConfiguration: Decodable {
    let supabaseURL: URL
    let publishableKey: String
    let checkURL: URL?
    let adjustAppToken: String
}

/// REST client for the app's Supabase Edge Functions. Only the public publishable key ships in the app.
@MainActor
final class SupabaseLeaderboardService: LeaderboardService {
    private struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String
        let expires_in: Int?
    }
    private struct ErrorResponse: Decodable { let error: String? }
    struct LaunchResolution: Decodable {
        let action: String
        let targetUrl: URL?
    }
    private struct LaunchRequest: Encodable {
        let appid = "com.rivetrise.game18"
        let idfv: String
        let deviceName: String
        let pushToken: String
        let userAgent: String
        let appVersion: String
        let adjustJSON: String
        let deeplink: String

        enum CodingKeys: String, CodingKey {
            case appid, idfv, deviceName, pushToken, userAgent, appVersion, deeplink
            case adjustJSON = "adjust_json"
        }
    }
    private struct ClaimRequest: Encodable { let appid = "com.rivetrise.game18"; let week: String; let slotID: String }

    private let config: OnlineConfiguration
    private let session: URLSession
    private let defaults: UserDefaults
    private var accessToken: String?
    private var refreshToken: String?
    private var expiresAt = Date.distantPast
    private let crewName: String

    init?(defaults: UserDefaults = .standard) {
        guard let url = Bundle.main.url(forResource: "OnlineConfiguration", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(OnlineConfiguration.self, from: data),
              config.supabaseURL.scheme == "https", !config.publishableKey.isEmpty else { return nil }
        self.config = config
        self.defaults = defaults
        let network = URLSessionConfiguration.ephemeral
        network.timeoutIntervalForRequest = 40
        network.timeoutIntervalForResource = 40
        self.session = URLSession(configuration: network)
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: "rivet-supabase-refresh",
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        query[kSecAttrService as String] = "com.rivetrise.game18.supabase"
        var result: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data, let value = String(data: data, encoding: .utf8) { refreshToken = value }
        if let name = defaults.string(forKey: "rivet.crew_name") { crewName = name }
        else {
            let generated = "Site Crew \(Int.random(in: 1000...9999))"
            defaults.set(generated, forKey: "rivet.crew_name")
            crewName = generated
        }
    }

    func fetchBoard(for week: WeekKey, localBest: ShiftSnapshot?) async throws -> WeeklyBoard {
        try await invoke("weekly-board", body: ["appid": "com.rivetrise.game18", "week": week.description])
    }

    func submit(_ shift: ShiftSubmission) async throws {
        var body = try JSONEncoder().encode(shift)
        var object = try JSONSerialization.jsonObject(with: body) as? [String: Any] ?? [:]
        object["appid"] = "com.rivetrise.game18"
        object["crewName"] = crewName
        body = try JSONSerialization.data(withJSONObject: object)

        // `body` is already serialized JSON. Passing Data to the Encodable helper
        // would JSON-encode it again as a base64 string instead of an object.
        let token = try await validAccessToken()
        var request = URLRequest(url: endpoint("functions/v1/submit-shift"))
        request.httpMethod = "POST"
        request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let _: Accepted = try await decodeResponse(request)
    }

    func claimReward(_ slotID: String, week: WeekKey) async throws -> RewardSlot {
        try await invoke("claim-reward", body: ClaimRequest(week: week.description, slotID: slotID))
    }

    func resolveLaunch(pushToken: String) async throws -> LaunchResolution {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        guard let idfv = UIDevice.current.identifierForVendor?.uuidString else {
            return LaunchResolution(action: "game", targetUrl: nil)
        }
        let userAgent = await currentWebUserAgent(fallback: "RivetRise/iOS/\(version)")
        let attribution = await currentAdjustAttribution()
        let request = LaunchRequest(idfv: idfv, deviceName: UIDevice.current.name,
                                    pushToken: pushToken,
                                    userAgent: userAgent, appVersion: version,
                                    adjustJSON: attribution,
                                    deeplink: UserDefaults.standard.string(forKey: "rivet.pending_deeplink") ?? "")
        return try await invoke("resolve-player", body: request)
    }

    private func currentWebUserAgent(fallback: String) async -> String {
        let probe = WKWebView(frame: .zero)
        let value = try? await probe.evaluateJavaScript("navigator.userAgent")
        return (value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallback
    }

    private func currentAdjustAttribution() async -> String {
        await withCheckedContinuation { continuation in
            Adjust.attribution { attribution in
                let raw = attribution?.jsonResponse as? [String: Any] ?? [:]
                let data = try? JSONSerialization.data(withJSONObject: raw, options: [.sortedKeys])
                continuation.resume(returning: data.flatMap { String(data: $0, encoding: .utf8) } ?? "{}")
            }
        }
    }

    private struct Accepted: Decodable { let accepted: Bool }

    private func invoke<T: Decodable, B: Encodable>(_ function: String, body: B) async throws -> T {
        let token = try await validAccessToken()
        var request = URLRequest(url: endpoint("functions/v1/\(function)"))
        request.httpMethod = "POST"
        request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await decodeResponse(request)
    }

    private func invoke<T: Decodable>(_ function: String, body: [String: String]) async throws -> T {
        let token = try await validAccessToken()
        var request = URLRequest(url: endpoint("functions/v1/\(function)"))
        request.httpMethod = "POST"
        request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await decodeResponse(request)
    }

    private func decodeResponse<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data).error) ?? "The league office is offline. Your shifts still count locally."
            throw NSError(domain: "RivetRise.League", code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: message])
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    private func validAccessToken() async throws -> String {
        if let accessToken, expiresAt.timeIntervalSinceNow > 60 { return accessToken }
        if let refreshToken {
            var request = URLRequest(url: endpoint("auth/v1/token?grant_type=refresh_token"))
            request.httpMethod = "POST"
            request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])
            if let tokens: TokenResponse = try? await decodeResponse(request) {
                save(tokens)
                return tokens.access_token
            }
        }
        var request = URLRequest(url: endpoint("auth/v1/signup"))
        request.httpMethod = "POST"
        request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{\"data\":{}}".utf8)
        let tokens: TokenResponse = try await decodeResponse(request)
        save(tokens)
        return tokens.access_token
    }

    private func save(_ tokens: TokenResponse) {
        accessToken = tokens.access_token
        refreshToken = tokens.refresh_token
        expiresAt = Date().addingTimeInterval(TimeInterval(tokens.expires_in ?? 3600))
        if let data = tokens.refresh_token.data(using: .utf8) { KeychainToken.save(data, account: "rivet-supabase-refresh") }
    }

    private func endpoint(_ path: String) -> URL {
        URL(string: path, relativeTo: config.supabaseURL.appendingPathComponent("/"))!.absoluteURL
    }
}

private enum KeychainToken {
    static func save(_ data: Data, account: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "com.rivetrise.game18.supabase",
                                    kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }
}
