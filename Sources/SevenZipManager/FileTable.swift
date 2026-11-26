import AppKit
import SwiftUI

struct FileTable: NSViewRepresentable {
    @ObservedObject var browser: Browser

    func makeCoordinator() -> Coordinator { Coordinator(browser) }
    func makeNSView(context: Context) -> NSScrollView {
        let table = NSTableView()
        table.allowsMultipleSelection = true
        table.allowsColumnResizing = true
        table.rowHeight = 21
        table.style = .plain
        table.target = context.coordinator
        table.doubleAction = #selector(Coordinator.activate(_:))
        for (id, title, width) in [("name","名稱",330),("size","大小",110),("packed","壓縮後大小",110),("modified","修改時間",170)] {
            let column = NSTableColumn(identifier: .init(id))
            column.title = title
            column.width = CGFloat(width)
            column.minWidth = 64
            column.sortDescriptorPrototype = NSSortDescriptor(key: id, ascending: true)
            table.addTableColumn(column)
        }
        table.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let coordinator = context.coordinator
        table.delegate = coordinator
        table.dataSource = coordinator
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.documentView = table
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let table = scroll.documentView as? NSTableView else { return }
        let c = context.coordinator
        table.tableColumn(withIdentifier: .init("packed"))?.isHidden = browser.archive == nil
        c.updating = true
        if c.source != browser.rows {
            c.source = browser.rows
            c.sort(table)
        }
        c.syncSelection(table)
        c.updating = false
    }

    @MainActor final class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
        let browser: Browser
        var source = [Item]()
        var sorted = [Item]()
        var updating = false
        init(_ browser: Browser) { self.browser = browser }

        func sort(_ table: NSTableView) {
            let descriptor = table.sortDescriptors.first
            sorted = source.sorted { lhs, rhs in
                if lhs.folder != rhs.folder { return lhs.folder }
                let a = descriptor?.ascending == false ? rhs : lhs
                let b = descriptor?.ascending == false ? lhs : rhs
                switch descriptor?.key {
                case "size" where a.size != b.size: return (a.size ?? -1) < (b.size ?? -1)
                case "packed" where a.packed != b.packed: return (a.packed ?? -1) < (b.packed ?? -1)
                case "modified" where a.modified != b.modified: return a.modified < b.modified
                default: return a.name.localizedStandardCompare(b.name) == .orderedAscending
                }
            }
            table.reloadData()
        }

        func syncSelection(_ table: NSTableView) {
            let indexes = IndexSet(sorted.indices.filter { browser.selected.contains(sorted[$0].id) })
            if indexes != table.selectedRowIndexes {
                table.selectRowIndexes(indexes, byExtendingSelection: false)
            }
        }

        func tableView(_ table: NSTableView, sortDescriptorsDidChange old: [NSSortDescriptor]) {
            updating = true
            sort(table)
            syncSelection(table)
            updating = false
        }
        func numberOfRows(in tableView: NSTableView) -> Int { sorted.count }
        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !updating, let table = notification.object as? NSTableView else { return }
            browser.selected = Set(table.selectedRowIndexes.compactMap { sorted.indices.contains($0) ? sorted[$0].id : nil })
        }
        @objc func activate(_ table: NSTableView) {
            guard sorted.indices.contains(table.clickedRow), !browser.busy else { return }
            browser.open(sorted[table.clickedRow])
        }
        func tableView(_ table: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
            guard let key = column?.identifier, sorted.indices.contains(row) else { return nil }
            let item = sorted[row]
            let cell = table.makeView(withIdentifier: key, owner: nil) as? NSTableCellView ?? makeCell(key)
            switch key.rawValue {
            case "name":
                cell.textField?.stringValue = item.name
                let icon = item.folder ? "folder.fill" : Archive.formats.contains((item.name as NSString).pathExtension.lowercased()) ? "archivebox.fill" : "doc"
                cell.imageView?.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
                cell.imageView?.contentTintColor = item.folder ? .systemOrange : .secondaryLabelColor
            case "size": cell.textField?.stringValue = item.size?.formatted() ?? ""
            case "packed": cell.textField?.stringValue = item.packed?.formatted() ?? ""
            default: cell.textField?.stringValue = item.modified
            }
            return cell
        }
        func makeCell(_ key: NSUserInterfaceItemIdentifier) -> NSTableCellView {
            let cell = NSTableCellView()
            cell.identifier = key
            let label = NSTextField(labelWithString: "")
            label.font = .systemFont(ofSize: 12)
            label.lineBreakMode = .byTruncatingMiddle
            label.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(label)
            cell.textField = label
            var leading = cell.leadingAnchor
            if key.rawValue == "name" {
                let image = NSImageView()
                image.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(image)
                cell.imageView = image
                NSLayoutConstraint.activate([image.leadingAnchor.constraint(equalTo: leading), image.centerYAnchor.constraint(equalTo: cell.centerYAnchor), image.widthAnchor.constraint(equalToConstant: 16)])
                leading = image.trailingAnchor
            }
            if ["size","packed"].contains(key.rawValue) { label.alignment = .right }
            NSLayoutConstraint.activate([label.leadingAnchor.constraint(equalTo: leading, constant: 4), label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4), label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)])
            return cell
        }
    }
}
