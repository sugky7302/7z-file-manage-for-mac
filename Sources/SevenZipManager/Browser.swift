import AppKit
import SwiftUI

enum Command: String, CaseIterable {
    case add = "加入", extract = "解壓縮", test = "測試", copy = "複製", move = "移動", delete = "刪除", info = "資訊"
    var symbol: String {
        switch self {
        case .add: return "plus"
        case .extract: return "minus"
        case .test: return "checkmark"
        case .copy: return "arrow.right"
        case .move: return "arrow.right.to.line"
        case .delete: return "xmark"
        case .info: return "info.circle.fill"
        }
    }
    var color: Color {
        switch self {
        case .add, .copy: return .green
        case .extract, .move, .info: return .blue
        case .delete: return .red
        case .test: return .teal
        }
    }
}

@MainActor final class Browser: ObservableObject {
    @Published var directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    @Published var hasLocation = false
    let access = FileAccess()
    @Published var archive: URL?
    @Published var prefix = ""
    @Published var rows = [Item]()
    @Published var selected = Set<String>()
    @Published var address = ""
    @Published var busy = false
    @Published var status = ""
    @Published var dialog: Command?
    @Published var message: String?
    @Published var favorites = UserDefaults.standard.stringArray(forKey: "FavoriteDirectories") ?? []
    private var members = [Item]()
    var chosen: [Item] { rows.filter { selected.contains($0.id) } }
    var targets: [URL] { chosen.map { directory.appendingPathComponent($0.id) } }
    var archives: [URL] { archive.map { [$0] } ?? targets }
    var location: String { archive.map { $0.path + "/" + prefix } ?? directory.path }

    func job<T>(_ label: String, _ work: @escaping () throws -> T, done: @escaping (T) -> Void) {
        guard !busy else { return }
        busy = true
        status = label
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) { try work() }.value
                busy = false
                status = ""
                done(result)
            } catch {
                busy = false
                status = ""
                message = error.localizedDescription
                address = location
            }
        }
    }

    func pickLocation(near hint: URL? = nil) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.prompt = "開啟"
        panel.directoryURL = hint
        guard panel.runModal() == .OK, let url = panel.url else {
            address = hasLocation ? location : ""
            return
        }
        access.accept(url)
        browse(url)
    }

    func openFavorite(_ path: String) {
        if let url = access.restore(path) { browse(url) }
        else { pickLocation(near: URL(fileURLWithPath: path)) }
    }

    func browse(_ url: URL) {
        guard access.contains(url) else {
            pickLocation(near: url.hasDirectoryPath ? url : url.deletingLastPathComponent())
            return
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            message = "找不到項目。\n" + url.path
            address = location
            return
        }
        if isDirectory.boolValue {
            job("讀取資料夾…", {
                let keys: Set<URLResourceKey> = [.isDirectoryKey,.fileSizeKey,.contentModificationDateKey]
                let files = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                return try files.map { file in
                    let v = try file.resourceValues(forKeys: keys)
                    return Item(id: file.lastPathComponent, folder: v.isDirectory == true, size: v.isDirectory == true ? nil : v.fileSize.map(Int64.init),
                                modified: v.contentModificationDate.map(formatter.string(from:)) ?? "")
                }
            }) { list in
                self.directory = url
                self.archive = nil
                self.members = []
                self.prefix = ""
                self.show(list)
            }
        } else {
            job("開啟壓縮檔…", { try Archive.contents(url) }) { list in
                self.directory = url.deletingLastPathComponent()
                self.archive = url
                self.members = list
                self.inside("")
            }
        }
    }

    func show(_ list: [Item]) {
        hasLocation = true
        selected = []
        rows = list
        address = location
    }

    func inside(_ path: String) {
        prefix = path
        show(Archive.children(members, under: path))
    }

    func enterAddress() {
        if let archive, address.hasPrefix(archive.path + "/") {
            let target = String(address.dropFirst(archive.path.count + 1)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if target.isEmpty || members.contains(where: { ($0.folder && $0.id == target) || $0.id.hasPrefix(target + "/") }) {
                inside(target)
            } else {
                message = "壓縮檔內找不到這個資料夾。"
                address = location
            }
        } else {
            let path = (address as NSString).expandingTildeInPath
            browse(URL(fileURLWithPath: path, relativeTo: directory).standardizedFileURL)
        }
    }

    func up() {
        if archive != nil && !prefix.isEmpty { inside((prefix as NSString).deletingLastPathComponent) }
        else { browse(archive == nil ? directory.deletingLastPathComponent() : directory) }
    }

    func open(_ row: Item) {
        if archive != nil {
            if row.folder { inside(row.id) }
            else { selected = [row.id]; dialog = .extract }
        } else {
            let url = directory.appendingPathComponent(row.id)
            if row.folder || Archive.formats.contains(url.pathExtension.lowercased()) { browse(url) }
            else { NSWorkspace.shared.open(url) }
        }
    }

    func refresh() {
        if let file = archive {
            let path = prefix
            job("重新整理…", { try Archive.contents(file) }) { items in
                self.members = items
                self.inside(path)
            }
        } else { browse(directory) }
    }

    func available(_ cmd: Command) -> Bool {
        guard !busy else { return false }
        switch cmd {
        case .add, .move: return archive == nil && !selected.isEmpty
        case .test, .extract: return archive != nil || (!chosen.isEmpty && chosen.allSatisfy { !$0.folder })
        case .info: return !chosen.isEmpty || archive != nil
        default: return !selected.isEmpty
        }
    }

    func perform(_ cmd: Command) {
        guard available(cmd) else { return }
        switch cmd {
        case .test:
            let files = archives
            job("測試壓縮檔…", {
                for file in files { try Archive.run(["t","--",file.path]) }
            }) { self.message = "測試完成。所有檔案均通過完整性檢查。" }
        case .copy where archive == nil, .move:
            guard let destination = chooseFolder(directory) else { return }
            access.accept(destination)
            let sources = targets
            job(cmd.rawValue + "中…", {
                let fm = FileManager.default
                for source in sources {
                    let dest = destination.appendingPathComponent(source.lastPathComponent)
                    guard !fm.fileExists(atPath: dest.path) else { throw Failure("目的地已有同名項目。\n" + dest.path) }
                    let base = source.resolvingSymlinksInPath().standardizedFileURL.path + "/"
                    guard !dest.resolvingSymlinksInPath().standardizedFileURL.path.hasPrefix(base) else { throw Failure("請選擇來源資料夾以外的目的地。") }
                }
                for source in sources {
                    let dest = destination.appendingPathComponent(source.lastPathComponent)
                    if cmd == .copy { try fm.copyItem(at: source, to: dest) }
                    else { try fm.moveItem(at: source, to: dest) }
                }
            }) { self.refresh() }
        case .copy: dialog = .extract
        case .info:
            if chosen.isEmpty { message = location }
            else { message = chosen.map { item in
                [item.id, item.size.map { "\($0) 位元組" }, item.modified].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "　")
            }.joined(separator: "\n") }
        default: dialog = cmd
        }
    }

    func deleteItems() {
        let paths = Array(selected), sources = targets, file = archive
        if let file, !access.contains(file.deletingLastPathComponent()) {
            message = "要修改壓縮檔，請先從「開啟」選取它所在的資料夾。"
            return
        }
        job("刪除中…", {
            if let file { try Archive.run(["d","--",file.path] + paths) }
            else { for url in sources { try FileManager.default.trashItem(at: url, resultingItemURL: nil) } }
        }) { self.refresh() }
    }

    func create(_ output: URL, format: String, level: Int) {
        guard access.contains(output.deletingLastPathComponent()) else {
            message = "請按「瀏覽」選取壓縮檔的目的地資料夾。"
            return
        }
        let paths = Array(selected), dir = directory, sources = targets
        let destination = output.standardizedFileURL.resolvingSymlinksInPath().path
        if sources.contains(where: { let p = $0.standardizedFileURL.resolvingSymlinksInPath().path; return destination == p || destination.hasPrefix(p + "/") }) {
            message = "請將壓縮檔儲存在所選項目之外。"
            return
        }
        job("建立壓縮檔…", {
            guard !FileManager.default.fileExists(atPath: output.path) else { throw Failure("已有同名檔案。請使用其他名稱。") }
            try Archive.run(["a","-t" + format,"-mx=" + String(level),"--",output.path] + paths.map { "./" + $0 }, at: dir)
        }) { self.browse(output.deletingLastPathComponent()) }
    }

    func extract(_ output: URL, policy: String) {
        guard access.contains(output) else {
            message = "請按「瀏覽」選取解壓縮目的地。"
            return
        }
        let files = archives, paths = archive == nil ? [] : Array(selected)
        job("解壓縮中…", {
            for file in files { try Archive.run(["x",policy,"-o" + output.path,"--",file.path] + paths) }
        }) { self.refresh() }
    }

    func clearFavorites() {
        favorites = []
        UserDefaults.standard.removeObject(forKey: "FavoriteDirectories")
        access.clearBookmarks()
    }

    func favorite() {
        guard !favorites.contains(directory.path) else { return }
        do { try access.remember(directory) }
        catch { message = error.localizedDescription; return }
        favorites.append(directory.path)
        UserDefaults.standard.set(favorites, forKey: "FavoriteDirectories")
    }
}

@MainActor func chooseFolder(_ initial: URL) -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.canCreateDirectories = true
    panel.directoryURL = initial
    return panel.runModal() == .OK ? panel.url : nil
}
