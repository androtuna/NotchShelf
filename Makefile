.PHONY: all project build test dmg clean release

PROJECT = NotchShelf.xcodeproj
SCHEME = NotchShelf
CONFIGURATION = Release
DERIVED = build/dist

all: project build

# Generate Xcode project using XcodeGen
project:
	@which xcodegen >/dev/null 2>&1 || (echo "Hata: xcodegen yüklü değil. 'brew install xcodegen' ile yükleyin." && exit 1)
	xcodegen generate

# Run unit tests
test: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-derivedDataPath build/DerivedData \
		test -destination "platform=macOS"

# Build Release binary (ad-hoc signed for local testing)
build: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) \
		-derivedDataPath $(DERIVED) -destination "platform=macOS" \
		CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual \
		clean build

# Package app into a distributable DMG image
dmg: build
	./scripts/create-dmg.sh "$(DERIVED)/Build/Products/$(CONFIGURATION)/$(SCHEME).app" build/artifacts

# Full release pipeline (sign, notarize, staple, zip & dmg)
release:
	./scripts/release.sh

# Clean build artifacts
clean:
	rm -rf build DerivedData $(PROJECT) Generated
