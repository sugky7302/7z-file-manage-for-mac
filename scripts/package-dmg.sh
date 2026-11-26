#!/bin/sh
set -eu

app=$1
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
output="build/7-Zip-File-Manager-${version}-arm64.dmg"
mkdir -p build
work=$(mktemp -d "build/.package.XXXXXX")
trap 'rm -rf "$work"' EXIT
mkdir "$work/payload"
ditto "$app" "$work/payload/7-Zip File Manager.app"
ln -s /Applications "$work/payload/Applications"
cp ThirdParty/7z2606-src.tar.xz "$work/payload/"
cp LICENSE "$work/payload/GUI-LICENSE.txt"
codesign --verify --deep --strict "$work/payload/7-Zip File Manager.app"
hdiutil create -fs HFS+ -format UDZO -volname "7-Zip File Manager" -srcfolder "$work/payload" "$work/release.dmg"
hdiutil verify "$work/release.dmg"
mv "$work/release.dmg" "$output"
shasum -a 256 "$output"
