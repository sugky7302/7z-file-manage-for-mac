import AppKit
import SwiftUI

@main struct ManagerApp: App {
    @StateObject private var browser = Browser()
    var body: some Scene {
        Window("7-Zip File Manager", id: "manager") {
            ManagerView(browser: browser)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .defaultSize(width: 900, height: 570)
        .commands {
            CommandMenu("壓縮檔") {
                ForEach(Command.allCases, id: \.self) { cmd in
                    Button(cmd.rawValue) { browser.perform(cmd) }.disabled(!browser.available(cmd))
                }
            }
        }
    }
}

struct ManagerView: View {
    @ObservedObject var browser: Browser
    @State private var showAbout = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Menu("檔案") {
                    Button("開啟…") { browser.pickLocation() }.keyboardShortcut("o")
                    ForEach(Command.allCases, id: \.self) { cmd in
                        Button(cmd.rawValue) { browser.perform(cmd) }.disabled(!browser.available(cmd))
                    }
                }
                Menu("編輯") {
                    Button("全選") { browser.selected = Set(browser.rows.map(\.id)) }
                    Button("取消選取") { browser.selected = [] }
                }
                Menu("檢視") {
                    Button("上一層") { browser.up() }.disabled(!browser.hasLocation)
                    Button("重新整理") { browser.refresh() }.disabled(!browser.hasLocation).keyboardShortcut("r")
                }
                Menu("我的最愛") {
                    Button("加入目前資料夾") { browser.favorite() }.disabled(!browser.hasLocation || browser.archive != nil || browser.favorites.contains(browser.directory.path))
                    Divider()
                    Button("清除我的最愛") { browser.clearFavorites() }.disabled(browser.favorites.isEmpty)
                    ForEach(browser.favorites, id: \.self) { path in
                        Button(path) { browser.openFavorite(path) }
                    }
                }
                Menu("工具") {
                    Button("在 Finder 顯示目前位置") {
                        NSWorkspace.shared.activateFileViewerSelecting([browser.archive ?? browser.directory])
                    }
                }
                Menu("說明") {
                    Button("關於 7-Zip File Manager") { showAbout = true }
                    Button("隱私權政策") {
                        if let url = Bundle.main.url(forResource: "Privacy", withExtension: "txt") { NSWorkspace.shared.open(url) }
                    }
                    Button("第三方軟體聲明") {
                        if let url = Bundle.main.url(forResource: "ThirdParty", withExtension: "txt") { NSWorkspace.shared.open(url) }
                    }
                    Button("7-Zip 授權條款") {
                        if let url = Bundle.main.url(forResource: "License", withExtension: "txt") { NSWorkspace.shared.open(url) }
                    }
                }
                Spacer()
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize(horizontal: true, vertical: false)
            .font(.system(size: 13)).padding(.horizontal, 10).padding(.vertical, 5)
            Divider()
            HStack(spacing: 1) {
                ForEach(Command.allCases, id: \.self) { cmd in
                    Button { browser.perform(cmd) } label: {
                        VStack(spacing: 3) {
                            Image(systemName: cmd.symbol).font(.system(size: 26, weight: .bold)).foregroundStyle(cmd.color)
                                .frame(height: 28)
                            Text(cmd.rawValue).font(.system(size: 12))
                        }.frame(width: 59, height: 51).contentShape(Rectangle())
                    }.buttonStyle(.plain).help(cmd.rawValue)
                        .disabled(!browser.available(cmd)).opacity(browser.available(cmd) ? 1 : 0.48)
                }
                Spacer()
            }.padding(.horizontal, 5).padding(.vertical, 3)
            Divider()
            HStack(spacing: 7) {
                Button { browser.up() } label: { Image(systemName: "arrow.up") }.help("上一層").disabled(!browser.hasLocation)
                TextField("路徑", text: $browser.address).onSubmit { browser.enterAddress() }
                    .accessibilityLabel("路徑")
            }.padding(.horizontal, 8).padding(.vertical, 5)
            Divider()
            if browser.hasLocation {
                FileTable(browser: browser)
            } else {
                VStack(spacing: 12) {
                    Text("選取資料夾或壓縮檔以開始瀏覽。")
                    Button("開啟…") { browser.pickLocation() }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            HStack(spacing: 12) {
                if browser.busy { ProgressView().controlSize(.small); Text(browser.status) }
                else {
                    Text("\(browser.rows.count) 個項目")
                    Divider()
                    Text("已選取 \(browser.selected.count) 個項目")
                    if !browser.selected.isEmpty {
                        Text(ByteCountFormatter.string(fromByteCount: browser.chosen.compactMap(\.size).reduce(0,+), countStyle: .file))
                    }
                }
                Spacer()
            }.font(.system(size: 12)).padding(.horizontal, 9).frame(height: 25)
        }
        .background(Color(nsColor: .windowBackgroundColor)).disabled(browser.busy)
        .frame(minWidth: 600, minHeight: 340)
        .sheet(item: Binding(get: { browser.dialog.map(DialogID.init) }, set: { browser.dialog = $0?.command })) { sheet in
            OperationView(browser: browser, command: sheet.command)
        }
        .alert("7-Zip File Manager", isPresented: Binding(get: { browser.message != nil }, set: { if !$0 { browser.message = nil } })) {
            Button("確定") { browser.message = nil }
        } message: { Text(browser.message ?? "") }
        .alert("關於 7-Zip File Manager", isPresented: $showAbout) {
            Button("確定") {}
        } message: { Text("macOS 檔案管理介面\n壓縮引擎：7-Zip 26.06") }
    }

}

private struct DialogID: Identifiable {
    let command: Command
    var id: Command { command }
}

struct OperationView: View {
    @ObservedObject var browser: Browser
    let command: Command
    @State private var path: String
    @State private var format = "7z"
    @State private var level = 5
    @State private var policy = "-aos"

    init(browser: Browser, command: Command) {
        self.browser = browser
        self.command = command
        let name = browser.chosen.first?.name ?? "Archive"
        let suggested = command == .add ? browser.directory.appendingPathComponent(name + ".7z") :
            browser.directory.appendingPathComponent(browser.archives.first?.deletingPathExtension().lastPathComponent ?? "解壓縮")
        _path = State(initialValue: suggested.path)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(command == .add ? "加入壓縮檔" : command.rawValue).font(.headline)
            if command == .delete {
                Text(browser.archive == nil ? "將所選的 \(browser.selected.count) 個項目移到垃圾桶？" : "從壓縮檔永久刪除所選的 \(browser.selected.count) 個項目？")
            } else {
                Text(command == .add ? "壓縮檔路徑" : "解壓縮目的地")
                HStack {
                    TextField("完整路徑", text: $path)
                    Button("瀏覽…") { choose() }
                }
                if command == .add {
                    Picker("壓縮格式", selection: $format) { Text("7z").tag("7z"); Text("zip").tag("zip") }
                        .onChange(of: format) { newFormat in path = (path as NSString).deletingPathExtension + "." + newFormat }
                    Picker("壓縮等級", selection: $level) {
                        ForEach([0,1,3,5,7,9], id: \.self) { value in
                            Text([0:"僅儲存",1:"最快",3:"快速",5:"標準",7:"最大",9:"極致"][value] ?? "").tag(value)
                        }
                    }
                } else {
                    Picker("已有同名檔案時", selection: $policy) {
                        Text("略過").tag("-aos"); Text("覆寫").tag("-aoa"); Text("自動重新命名").tag("-aou")
                    }
                }
            }
            Divider()
            HStack {
                Spacer()
                Button("取消") { browser.dialog = nil }.keyboardShortcut(.cancelAction)
                Button(command == .delete ? "刪除" : "確定") {
                    browser.dialog = nil
                    let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, relativeTo: browser.directory).standardizedFileURL
                    switch command {
                    case .add: browser.create(url, format: format, level: level)
                    case .extract: browser.extract(url, policy: policy)
                    case .delete: browser.deleteItems()
                    default: break
                    }
                }.keyboardShortcut(.defaultAction).disabled(command != .delete && path.isEmpty)
            }
        }.padding(20).frame(width: 450)
    }
    func choose() {
        let suggested = URL(fileURLWithPath: path)
        guard let folder = chooseFolder(suggested.deletingLastPathComponent()) else { return }
        browser.access.accept(folder)
        path = command == .add ? folder.appendingPathComponent(suggested.lastPathComponent).path : folder.path
    }
}
