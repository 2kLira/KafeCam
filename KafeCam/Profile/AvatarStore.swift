import SwiftUI

@MainActor
final class AvatarStore: ObservableObject {
    @Published var avatarKey: String = ""
    @Published var image: UIImage? = nil

    init() {
        // Synchronous warm read from disk for instant first paint
        if let key = UserDefaults.standard.string(forKey: "avatarKey"),
           let img = loadFromDiskIfAvailable(key: key) {
            self.avatarKey = key
            self.image = img
        }
    }

    func set(image: UIImage, key: String) {
        self.image = image
        self.avatarKey = key
        UserDefaults.standard.set(key, forKey: "avatarKey")
        UserDefaults.standard.set(true, forKey: "avatar.localOnly")
        saveToDisk(image: image, key: key)
        saveStableAlias(image)
        // Also persist a per-user alias so it survives logout/login cycles
        #if canImport(Supabase)
        Task { [weak self] in
            if let uid = try? await SupaAuthService.currentUserId().uuidString.lowercased() {
                self?.savePerUserAlias(image, userId: uid)
                UserDefaults.standard.set(uid, forKey: "avatar.owner")
            }
        }
        #endif
    }

    func clear() {
        self.image = nil
        self.avatarKey = ""
        UserDefaults.standard.removeObject(forKey: "avatarKey")
        UserDefaults.standard.removeObject(forKey: "avatar.localOnly")
        removeFromDisk()
        removeStableAlias()
    }

    /// Warm start: load from disk immediately if present, then refresh from Auth/Storage.
    func warmStart() async {
        var currentUid: String? = nil
        #if canImport(Supabase)
        if let uid = try? await SupaAuthService.currentUserId().uuidString { currentUid = uid }
        #endif
        let previousOwner = UserDefaults.standard.string(forKey: "avatar.owner")
        // If owner changed, CLEAR the avatar and load the new user's avatar
        if previousOwner != nil && currentUid != nil && previousOwner != currentUid?.lowercased() {
            self.image = nil
            self.avatarKey = ""
            UserDefaults.standard.removeObject(forKey: "avatarKey")
            UserDefaults.standard.set(false, forKey: "avatar.localOnly")
        }
        // Load the current user's avatar
        if let uid = currentUid?.lowercased() {
            if let img = loadStableAlias(userId: uid) {
                self.image = img
            } else {
                // Try to load from remote for this user
                await loadFromAuth()
            }
            UserDefaults.standard.set(uid, forKey: "avatar.owner")
        }
    }

    func loadFromAuth() async {
        #if canImport(Supabase)
        do {
            let session = try await SupaClient.shared.auth.session
            if let key = session.user.userMetadata["avatar_key"]?.stringValue, !key.isEmpty {
                if let cached = loadFromDiskIfAvailable(key: key) ?? loadStableAlias() {
                    self.avatarKey = key
                    self.image = cached
                } else {
                    await loadImage(for: key)
                }
            }
        } catch { }
        #endif
    }

    func loadImage(for key: String) async {
        #if canImport(Supabase)
        do {
            let storage = StorageRepository()
            if let url = try? await storage.signedDownloadURL(objectKey: key, bucket: "avatars", expiresIn: 600) {
                let (data, resp) = try await URLSession.shared.data(from: url)
                if let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode, let img = UIImage(data: data) {
                    self.image = img
                    self.avatarKey = key
                    UserDefaults.standard.set(key, forKey: "avatarKey")
                    saveToDisk(image: img, key: key)
                    saveStableAlias(img)
                }
            }
        } catch { }
        #endif
    }

    // MARK: - Disk cache (Caches/avatars/<key>)
    private func cacheDir() -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("avatars", isDirectory: true)
    }

    private func ensureDir() {
        guard let dir = cacheDir() else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private func fileURL(for key: String) -> URL? {
        guard let dir = cacheDir() else { return nil }
        return dir.appendingPathComponent(key.replacingOccurrences(of: "/", with: "_"))
    }

    private func saveToDisk(image: UIImage, key: String) {
        ensureDir()
        guard let url = fileURL(for: key), let data = image.jpegData(compressionQuality: 0.9) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func loadFromDiskIfAvailable(key: String) -> UIImage? {
        guard let url = fileURL(for: key), FileManager.default.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    // Stable alias for avatar (local-only instant load regardless of key)
    private func stableAliasURL() -> URL? {
        cacheDir()?.appendingPathComponent("avatar_current.jpg")
    }
    private func stableAliasURL(userId: String) -> URL? {
        cacheDir()?.appendingPathComponent("avatar_current_\(userId).jpg")
    }

    private func saveStableAlias(_ image: UIImage) {
        ensureDir()
        guard let url = stableAliasURL(), let data = image.jpegData(compressionQuality: 0.9) else { return }
        try? data.write(to: url, options: .atomic)
    }
    private func savePerUserAlias(_ image: UIImage, userId: String) {
        ensureDir()
        guard let url = stableAliasURL(userId: userId), let data = image.jpegData(compressionQuality: 0.9) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func loadStableAlias() -> UIImage? {
        guard let url = stableAliasURL(), FileManager.default.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
    private func loadStableAlias(userId: String) -> UIImage? {
        guard let url = stableAliasURL(userId: userId), FileManager.default.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    private func removeFromDisk() {
        if let key = UserDefaults.standard.string(forKey: "avatarKey"), let url = fileURL(for: key) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func removeStableAlias() {
        if let url = stableAliasURL() { try? FileManager.default.removeItem(at: url) }
        // Keep per-user files; they are keyed and safe across sessions
    }
}


