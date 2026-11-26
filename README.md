# 7-Zip File Manager for macOS

English · [繁體中文](README.zh-TW.md)

An unofficial macOS interface for 7-Zip, written in Swift. Browse folders and archives using a toolbar and file list modeled on the Windows 7-Zip File Manager. The app uses the bundled 7-Zip 26.06 command-line tool (`7zz`) to create and extract archives.

## Installation

Requires an Apple Silicon Mac running macOS 13 or later.

1. Download the DMG from [GitHub Releases](https://github.com/sugky7302/7z-file-manage-for-mac/releases).
2. Open the DMG and drag **7-Zip File Manager** into **Applications**.
3. Launch the app and select a folder or archive to browse.

The release uses an ad hoc signature and has not been notarized by Apple. Gatekeeper may block the app when you first open it.

## Features

- Create 7z and ZIP archives and choose the compression level.
- Browse archive contents, extract selected items, and test archive integrity.
- Copy, move, and delete items. Save frequently used folders to Favorites.

## Build from source

On an Apple Silicon Mac with Xcode installed, run `make dmg` from the project directory. The build produces an ad hoc signed app and writes the DMG to `build/`.

## License

The GUI is licensed under the [Apache License 2.0](LICENSE). The bundled `7zz` executable is developed by Igor Pavlov and other contributors. Most of its code is licensed under the GNU LGPL 2.1 or later. Some components use BSD licenses or carry the unRAR restriction. [7-Zip license notice](executable/License.txt) · [LGPL 2.1 license text](Store/Resources/LGPL-2.1.txt)

Both the repository and the DMG include the corresponding source code for 7-Zip 26.06. [Bundled source archive](ThirdParty/7z2606-src.tar.xz) · [7-Zip website](https://www.7-zip.org/) · [Upstream release](https://github.com/ip7z/7zip/releases/tag/26.06)
