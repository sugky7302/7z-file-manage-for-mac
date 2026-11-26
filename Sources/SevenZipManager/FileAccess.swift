import Foundation

/// 只有使用者選取的 URL 或已儲存的書籤可以建立存取範圍。
final class FileAccess {
    private struct Grant {
        let url: URL
        let path: String
        let directory: Bool
        let scoped: Bool
    }
    private var grants = [Grant]()
    private let key = "FavoriteFolderBookmarks"

    func accept(_ url: URL) {
        if contains(url) { return }
        let scoped = url.startAccessingSecurityScopedResource()
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        let directory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        grants.append(Grant(url: url, path: path, directory: directory, scoped: scoped))
    }

    func contains(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        return grants.contains { grant in
            path == grant.path || (grant.directory && path.hasPrefix(grant.path == "/" ? "/" : grant.path + "/"))
        }
    }

    func remember(_ url: URL, as name: String? = nil) throws {
        let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        var stored = UserDefaults.standard.dictionary(forKey: key) as? [String: Data] ?? [:]
        stored[name ?? url.path] = data
        UserDefaults.standard.set(stored, forKey: key)
    }

    func restore(_ path: String) -> URL? {
        guard let data = UserDefaults.standard.dictionary(forKey: key)?[path] as? Data else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI],
                                 relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        accept(url)
        if stale { try? remember(url, as: path) }
        return url
    }

    func clearBookmarks() { UserDefaults.standard.removeObject(forKey: key) }

    deinit {
        for grant in grants where grant.scoped { grant.url.stopAccessingSecurityScopedResource() }
    }
}
