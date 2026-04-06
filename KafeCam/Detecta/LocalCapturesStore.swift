import Foundation
import UIKit

struct LocalCapturesStore {
    static let shared = LocalCapturesStore()

    private func baseDir() -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("captures", isDirectory: true)
    }

    private func ensureDir(_ dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private func userDir(for userId: String) -> URL? {
        guard let base = baseDir() else { return nil }
        let dir = base.appendingPathComponent(userId, isDirectory: true)
        ensureDir(dir)
        return dir
    }

    func save(image: UIImage, for userId: String) -> URL? {
        guard let dir = userDir(for: userId) else { return nil }
        let ts = Int(Date().timeIntervalSince1970)
        let name = "\(ts).jpg"
        let url = dir.appendingPathComponent(name)
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch { return nil }
    }

    func list(for userId: String) -> [URL] {
        guard let dir = userDir(for: userId) else { return [] }
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])) ?? []
        return files.sorted { (a, b) -> Bool in
            let ad = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            let bd = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            return ad > bd
        }
    }
}


