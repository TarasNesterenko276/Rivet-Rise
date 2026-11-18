import Foundation

/// Everything the game saves: the profile and the shift log. Encoded as one JSON file.
struct SaveFile: Codable, Equatable {
    var version = 1
    var profile = PlayerProfile()
    /// Newest first.
    var runs: [RunRecord] = []
}

/// Where the save file lives. The in-memory variant keeps the bytes for tests and UI-test runs,
/// so re-opening a store on the same storage behaves like relaunching the app.
final class ProfileStorage {
    private let fileURL: URL?
    private var memory: Data?

    private init(fileURL: URL?) {
        self.fileURL = fileURL
    }

    static func inMemory() -> ProfileStorage { ProfileStorage(fileURL: nil) }

    static func file(at url: URL) -> ProfileStorage { ProfileStorage(fileURL: url) }

    func load() throws -> SaveFile? {
        let data: Data?
        if let fileURL {
            data = FileManager.default.fileExists(atPath: fileURL.path) ? try Data(contentsOf: fileURL) : nil
        } else {
            data = memory
        }
        guard let data else { return nil }
        return try Self.decoder.decode(SaveFile.self, from: data)
    }

    func save(_ file: SaveFile) throws {
        let data = try Self.encoder.encode(file)
        if let fileURL {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } else {
            memory = data
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

/// Builds the storage used by the app and by tests.
enum PersistenceController {
    /// Pass `inMemory: true` for tests and UI-test runs so nothing touches the player's real progress.
    static func makeStorage(inMemory: Bool = false) throws -> ProfileStorage {
        if inMemory { return .inMemory() }
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return .file(at: support.appendingPathComponent("RivetRise/save.json"))
    }
}
