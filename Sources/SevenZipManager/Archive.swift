import Foundation

struct Failure: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

struct Item: Identifiable, Equatable {
    let id: String
    let folder: Bool
    var size: Int64?
    var packed: Int64?
    var modified: String = ""
    var name: String { (id as NSString).lastPathComponent }
}

enum Archive {
    static let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/7zz")
    static let formats: Set<String> = ["7z","zip","rar","tar","gz","bz2","xz","tgz","tbz2","txz","zst","iso","dmg","cab","wim","arj","lzma","001","apk","jar","ipa","epub","deb","rpm","cpio","xar","lzh","vhd","vhdx","z"]

    @discardableResult
    static func run(_ args: [String], at directory: URL? = nil) throws -> String {
        let task = Process()
        task.executableURL = helper
        task.currentDirectoryURL = directory
        task.arguments = [args[0], "-sccUTF-8", "-spd"] + Array(args.dropFirst())
        task.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        try task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self)
        guard task.terminationStatus == 0 else {
            throw Failure("7-Zip 結束代碼 \(task.terminationStatus)\n\(output.suffix(1800))")
        }
        return output
    }

    static func contents(_ file: URL) throws -> [Item] {
        let listing = try run(["l","-slt","-ba","--",file.path])
        return listing.components(separatedBy: "\n\n").compactMap { record in
            var fields = [String: String]()
            for line in record.components(separatedBy: "\n") {
                guard let sep = line.range(of: " = ") else { continue }
                fields[String(line[..<sep.lowerBound])] = String(line[sep.upperBound...])
            }
            guard let path = fields["Path"], !path.isEmpty else { return nil }
            return Item(id: path, folder: fields["Folder"] == "+" || fields["Attributes"]?.first == "D" || fields["Mode"]?.first == "d",
                        size: fields["Size"].flatMap(Int64.init), packed: fields["Packed Size"].flatMap(Int64.init),
                        modified: String((fields["Modified"] ?? "").prefix(19)))
        }
    }

    static func children(_ items: [Item], under prefix: String) -> [Item] {
        var rows = [String: Item]()
        let base = prefix.isEmpty ? "" : prefix + "/"
        for item in items where item.id.hasPrefix(base) {
            let rest = item.id.dropFirst(base.count)
            guard !rest.isEmpty else { continue }
            if let slash = rest.firstIndex(of: "/") {
                let path = base + String(rest[..<slash])
                if rows[path] == nil { rows[path] = Item(id: path, folder: true) }
            } else {
                rows[item.id] = item
            }
        }
        return Array(rows.values)
    }
}
