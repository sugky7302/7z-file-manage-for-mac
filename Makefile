PROJECT := ParcelFold.xcodeproj
SCHEME := ParcelFold
PRODUCTS := .build/Xcode/Build/Products/Release

.PHONY: app dmg archive
app:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release -destination 'generic/platform=macOS' -derivedDataPath .build/Xcode CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= build

dmg: app
	sh scripts/package-dmg.sh "$(PRODUCTS)/7-Zip File Manager.app"

archive:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'generic/platform=macOS' -archivePath build/ParcelFold.xcarchive archive
