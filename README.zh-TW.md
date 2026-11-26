# 7-Zip File Manager for macOS

[English](README.md) · 繁體中文

以 Swift 開發的非官方 7-Zip 圖形介面。主視窗沿用 Windows 版常見的工具列與檔案清單。壓縮與解壓縮由內建的 7-Zip 26.06 命令列程式 `7zz` 執行。

## 安裝

1. 如果使用 Apple Silicon Mac，請從 [GitHub Releases](https://github.com/sugky7302/7z-file-manage-for-mac/releases) 下載 DMG。最低系統需求為 macOS 13。
2. 開啟 DMG，將「7-Zip File Manager」拖到「Applications」。
3. 開啟程式後，選取要瀏覽的資料夾或壓縮檔。

此版本使用本機簽章，尚未取得 Apple 公證。從網路下載後，Gatekeeper 可能會阻擋首次啟動。

## 功能

- 建立 7z 或 ZIP 壓縮檔，並設定壓縮等級。
- 瀏覽壓縮檔內容、解壓縮所選項目及測試完整性。
- 複製、移動及刪除項目，並以「我的最愛」保存資料夾位置。

## 自行建置

在已安裝 Xcode 的 Apple Silicon Mac 上，從專案目錄執行 `make dmg`。此指令使用本機簽章，會將 DMG 輸出至 `build/`。

## 授權

本專案的 GUI 採用 [Apache License 2.0](LICENSE)。內建的 `7zz` 由 Igor Pavlov 與其他貢獻者開發。其主要授權為 GNU LGPL 2.1 或更新版本。部分程式碼適用 BSD 授權及 unRAR 限制。[7-Zip 授權聲明](executable/License.txt) · [LGPL 2.1 全文](Store/Resources/LGPL-2.1.txt)

儲存庫與 DMG 均隨附 7-Zip 26.06 對應原始碼。[隨附原始碼](ThirdParty/7z2606-src.tar.xz) · [7-Zip 官方網站](https://www.7-zip.org/) · [上游版本](https://github.com/ip7z/7zip/releases/tag/26.06)
