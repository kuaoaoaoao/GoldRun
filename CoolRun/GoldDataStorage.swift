import Foundation

/// Keeps CoolRun data in one stable Application Support directory.
enum GoldDataStorage {
    static let directoryName = "CoolRun"

    static func fileURL(named fileName: String) -> URL {
        let directory = currentDirectory
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appendingPathComponent(fileName)
    }

    static func readableFileURLs(named fileName: String) -> [URL] {
        let url = fileURL(named: fileName)
        return FileManager.default.fileExists(atPath: url.path) ? [url] : []
    }

    private static var currentDirectory: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return appSupport.appendingPathComponent(directoryName, isDirectory: true)
    }

}
