import Foundation

public final class ImageStore {
    private let directory: URL

    public init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.directory = base.appendingPathComponent("LotteryChecker/images", isDirectory: true)
        }
    }

    private func ensureDir() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    public func save(_ data: Data, ext: String = "jpg") throws -> String {
        try ensureDir()
        let name = "\(UUID().uuidString).\(ext)"
        try data.write(to: url(for: name))
        return name
    }

    public func load(_ fileName: String) -> Data? {
        try? Data(contentsOf: url(for: fileName))
    }
}
