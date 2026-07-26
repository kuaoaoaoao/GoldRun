import Foundation

/// Keeps gold data in one stable location and discovers files created by older
/// sandboxed builds when the app's sandbox setting changes.
enum GoldDataStorage {
    static let directoryName = "coolRun"
    static let bundleIdentifier = "kuao.coolRun"

    static func fileURL(named fileName: String) -> URL {
        let directory = currentDirectory
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appendingPathComponent(fileName)
    }

    static func readableFileURLs(named fileName: String) -> [URL] {
        uniqueURLs(
            [fileURL(named: fileName)]
                + legacyDirectories.map { $0.appendingPathComponent(fileName) }
        ).filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// `UserDefaults` also moved when App Sandbox was disabled. Copy only the
    /// gold-position fields that are missing in the current preference domain.
    static func migrateLegacyGoldPreferencesIfNeeded() {
        let defaults = UserDefaults.standard
        let keys = ["goldHoldingGramsText", "goldHoldingAverageCostText"]
        guard keys.contains(where: { defaults.string(forKey: $0)?.isEmpty != false }) else { return }

        for preferencesURL in legacyPreferenceURLs where FileManager.default.fileExists(atPath: preferencesURL.path) {
            guard let values = NSDictionary(contentsOf: preferencesURL) as? [String: Any] else { continue }
            for key in keys where defaults.string(forKey: key)?.isEmpty != false {
                if let value = values[key] as? String, !value.isEmpty {
                    defaults.set(value, forKey: key)
                }
            }
        }
    }

    private static var currentDirectory: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return appSupport.appendingPathComponent(directoryName, isDirectory: true)
    }

    private static var legacyDirectories: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home
                .appendingPathComponent("Library/Containers", isDirectory: true)
                .appendingPathComponent(bundleIdentifier, isDirectory: true)
                .appendingPathComponent("Data/Library/Application Support", isDirectory: true)
                .appendingPathComponent(directoryName, isDirectory: true)
        ]
    }

    private static var legacyPreferenceURLs: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home
                .appendingPathComponent("Library/Containers", isDirectory: true)
                .appendingPathComponent(bundleIdentifier, isDirectory: true)
                .appendingPathComponent("Data/Library/Preferences", isDirectory: true)
                .appendingPathComponent("\(bundleIdentifier).plist")
        ]
    }

    private static func uniqueURLs(_ urls: [URL]) -> [URL] {
        var paths = Set<String>()
        return urls.filter { paths.insert($0.standardizedFileURL.path).inserted }
    }
}
