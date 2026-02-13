# ==============================================================================
# Mac AI Helper — Build & Packaging Makefile
# ==============================================================================
# Usage:
#   make release              — Ad-hoc: clean → build → app → sign → pkg + dmg
#   make release-signed       — Developer ID: clean → build → sign → notarize → staple → pkg + dmg
#   make app                  — Build Universal .app bundle only
#   make pkg                  — Create .pkg installer
#   make dmg                  — Create .dmg disk image
#   make clean                — Remove all build artifacts
#
# Variables (ad-hoc):
#   APP_VERSION               — Override version string (reads from Info.plist by default)
#
# Variables (Apple Developer — required for release-signed):
#   SIGNING_IDENTITY          — "Developer ID Application: Your Name (TEAMID)"
#   INSTALLER_SIGNING_IDENTITY — "Developer ID Installer: Your Name (TEAMID)"
#   APPLE_ID                  — Apple ID email for notarization
#   TEAM_ID                   — Apple Developer Team ID
#   APP_PASSWORD              — App-specific password (or @keychain:notarytool)
# ==============================================================================

# --- Configuration -----------------------------------------------------------

APP_NAME           := MacAIHelper
DISPLAY_NAME       := Mac AI Helper
BUNDLE_ID          := pro.kantora.MacAIHelper

# Signing identities: use "-" for ad-hoc, or set to your Developer ID
# Example: make release-signed \
#   SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
#   INSTALLER_SIGNING_IDENTITY="Developer ID Installer: Your Name (TEAMID)" \
#   APPLE_ID="you@example.com" TEAM_ID="XXXXXXXXXX" APP_PASSWORD="@keychain:notarytool"
SIGNING_IDENTITY            ?= -
INSTALLER_SIGNING_IDENTITY  ?= $(SIGNING_IDENTITY)

# Apple notarization credentials (required for release-signed)
APPLE_ID           ?=
TEAM_ID            ?=
APP_PASSWORD       ?=

# Directories
BUILD_DIR          := build
RELEASE_DIR        := $(BUILD_DIR)/release
PKG_DIR            := $(BUILD_DIR)/pkg
DMG_DIR            := $(BUILD_DIR)/dmg
ICONSET_DIR        := $(BUILD_DIR)/AppIcon.iconset

# App bundle paths
APP_BUNDLE         := $(RELEASE_DIR)/$(APP_NAME).app
APP_CONTENTS       := $(APP_BUNDLE)/Contents
APP_MACOS          := $(APP_CONTENTS)/MacOS
APP_RESOURCES      := $(APP_CONTENTS)/Resources

# Source files
INFO_PLIST         := SupportFiles/Info.plist
ENTITLEMENTS       := SupportFiles/MacAIHelper.entitlements
ENTITLEMENTS_ADHOC := SupportFiles/MacAIHelper-adhoc.entitlements
ICON_SVG           := SupportFiles/icon.svg
DISTRIBUTION_XML   := SupportFiles/distribution.xml

# SPM build outputs (separate scratch paths to avoid cross-architecture conflicts)
SPM_ARM64_BUILD    := .build-arm64
SPM_X86_64_BUILD   := .build-x86_64
ARM64_BINARY       := $(SPM_ARM64_BUILD)/arm64-apple-macosx/release/$(APP_NAME)
X86_64_BINARY      := $(SPM_X86_64_BUILD)/x86_64-apple-macosx/release/$(APP_NAME)
UNIVERSAL_BINARY   := $(BUILD_DIR)/$(APP_NAME)-universal
ARM64_BUNDLE       := $(SPM_ARM64_BUILD)/arm64-apple-macosx/release/$(APP_NAME)_$(APP_NAME).bundle
X86_64_BUNDLE      := $(SPM_X86_64_BUILD)/x86_64-apple-macosx/release/$(APP_NAME)_$(APP_NAME).bundle

# Read version from Info.plist (can be overridden via APP_VERSION=x.y.z)
APP_VERSION        ?= $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" $(INFO_PLIST) 2>/dev/null || echo "1.0.0")
BUILD_NUMBER       ?= $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleVersion" $(INFO_PLIST) 2>/dev/null || echo "1")

# Output artifacts
PKG_OUTPUT         := $(BUILD_DIR)/$(APP_NAME)-$(APP_VERSION).pkg
DMG_OUTPUT         := $(BUILD_DIR)/$(APP_NAME)-$(APP_VERSION).dmg
ICNS_OUTPUT        := $(BUILD_DIR)/AppIcon.icns

# --- Phony targets -----------------------------------------------------------

.PHONY: all release release-signed app sign pkg dmg clean build-arm64 build-x86_64 \
        universal-binary icon app-bundle notarize notarize-dmg staple staple-dmg \
        check-identity check-notarize-credentials help

# --- Default target ----------------------------------------------------------

all: app
	@echo "✅ Build complete: $(APP_BUNDLE)"

# --- Help --------------------------------------------------------------------

help:
	@echo ""
	@echo "Mac AI Helper — Build Targets"
	@echo "=============================="
	@echo ""
	@echo "  Development (ad-hoc signed):"
	@echo "  ─────────────────────────────"
	@echo "  make app               Build Universal .app bundle (ad-hoc signed)"
	@echo "  make release           Full ad-hoc pipeline: clean → app → sign → pkg + dmg"
	@echo ""
	@echo "  Distribution (Apple Developer signed):"
	@echo "  ────────────────────────────────────────"
	@echo "  make release-signed    Full pipeline: clean → app → sign → notarize → staple → pkg + dmg"
	@echo "  make sign              Code sign the .app bundle"
	@echo "  make notarize          Submit .app to Apple for notarization"
	@echo "  make notarize-dmg      Submit .dmg to Apple for notarization"
	@echo "  make staple            Staple notarization ticket to .app"
	@echo "  make staple-dmg        Staple notarization ticket to .dmg"
	@echo "  make pkg               Create .pkg installer"
	@echo "  make dmg               Create .dmg disk image"
	@echo ""
	@echo "  Utilities:"
	@echo "  ──────────"
	@echo "  make build-arm64       Build release binary for Apple Silicon"
	@echo "  make build-x86_64      Build release binary for Intel"
	@echo "  make universal-binary  Combine into Universal Binary"
	@echo "  make icon              Generate AppIcon.icns from SVG"
	@echo "  make check-identity    Verify signing identities are available"
	@echo "  make clean             Remove all build artifacts"
	@echo ""
	@echo "Variables (ad-hoc):"
	@echo "  APP_VERSION                   Override version (default: from Info.plist)"
	@echo ""
	@echo "Variables (Apple Developer):"
	@echo "  SIGNING_IDENTITY              Developer ID Application certificate name"
	@echo "  INSTALLER_SIGNING_IDENTITY    Developer ID Installer certificate name"
	@echo "  APPLE_ID                      Apple ID email for notarization"
	@echo "  TEAM_ID                       Apple Developer Team ID"
	@echo "  APP_PASSWORD                  App-specific password or @keychain:notarytool"
	@echo ""
	@echo "Example (ad-hoc):"
	@echo "  make release"
	@echo ""
	@echo "Example (Developer ID):"
	@echo '  make release-signed \'
	@echo '    SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \'
	@echo '    INSTALLER_SIGNING_IDENTITY="Developer ID Installer: Your Name (TEAMID)" \'
	@echo '    APPLE_ID="you@example.com" TEAM_ID="XXXXXXXXXX" \'
	@echo '    APP_PASSWORD="@keychain:notarytool"'
	@echo ""

# --- Validate signing identity -----------------------------------------------

check-identity:
	@echo "🔍 Checking available signing identities..."
	@echo ""
	@echo "Application signing identities:"
	@security find-identity -v -p codesigning | grep "Developer ID Application" || \
		echo "  ⚠️  No 'Developer ID Application' certificates found"
	@echo ""
	@echo "Installer signing identities:"
	@security find-identity -v -p basic | grep "Developer ID Installer" || \
		echo "  ⚠️  No 'Developer ID Installer' certificates found"
	@echo ""
	@if [ "$(SIGNING_IDENTITY)" != "-" ]; then \
		echo "Current SIGNING_IDENTITY: $(SIGNING_IDENTITY)"; \
		security find-identity -v -p codesigning | grep -q "$(SIGNING_IDENTITY)" && \
			echo "  ✅ Identity found in keychain" || \
			echo "  ❌ Identity NOT found in keychain"; \
	else \
		echo "Current SIGNING_IDENTITY: ad-hoc (-)"; \
	fi
	@echo ""

# --- Validate notarization credentials ---------------------------------------

check-notarize-credentials:
	@if [ -z "$(APPLE_ID)" ]; then \
		echo "❌ APPLE_ID is required for notarization"; \
		echo "   Set it via: make notarize APPLE_ID=you@example.com"; \
		exit 1; \
	fi
	@if [ -z "$(TEAM_ID)" ]; then \
		echo "❌ TEAM_ID is required for notarization"; \
		echo "   Set it via: make notarize TEAM_ID=XXXXXXXXXX"; \
		exit 1; \
	fi
	@if [ -z "$(APP_PASSWORD)" ]; then \
		echo "❌ APP_PASSWORD is required for notarization"; \
		echo "   Create an app-specific password at https://appleid.apple.com"; \
		echo "   Or store in keychain: xcrun notarytool store-credentials notarytool \\"; \
		echo "     --apple-id $(APPLE_ID) --team-id $(TEAM_ID)"; \
		echo "   Then use: APP_PASSWORD=@keychain:notarytool"; \
		exit 1; \
	fi

# --- Full release pipeline (ad-hoc) ------------------------------------------

release: clean app sign pkg dmg
	@echo ""
	@echo "🎉 Release $(APP_VERSION) built successfully! (ad-hoc signed)"
	@echo "   App:        $(APP_BUNDLE)"
	@echo "   Installer:  $(PKG_OUTPUT)"
	@echo "   Disk Image: $(DMG_OUTPUT)"
	@echo ""
	@echo "⚠️  Ad-hoc signed — for distribution, use: make release-signed"
	@echo ""

# --- Full release pipeline (Apple Developer signed + notarized) ---------------

release-signed: clean app sign notarize staple pkg dmg notarize-dmg staple-dmg
	@echo ""
	@echo "🎉 Release $(APP_VERSION) built, signed & notarized!"
	@echo "   App:        $(APP_BUNDLE)"
	@echo "   Installer:  $(PKG_OUTPUT)"
	@echo "   Disk Image: $(DMG_OUTPUT)"
	@echo ""
	@echo "✅ All artifacts are Developer ID signed and Apple notarized."
	@echo "   Ready for distribution outside the App Store."
	@echo ""

# --- Build for individual architectures --------------------------------------

build-arm64:
	@echo "🔨 Building for arm64 (Apple Silicon)..."
	swift build -c release --arch arm64 --scratch-path $(SPM_ARM64_BUILD)
	@echo "✅ arm64 build complete"

build-x86_64:
	@echo "🔨 Building for x86_64 (Intel)..."
	swift build -c release --arch x86_64 --scratch-path $(SPM_X86_64_BUILD)
	@echo "✅ x86_64 build complete"

# --- Create Universal Binary -------------------------------------------------

universal-binary: build-arm64 build-x86_64
	@echo "🔗 Creating Universal Binary..."
	@mkdir -p $(BUILD_DIR)
	lipo -create \
		$(ARM64_BINARY) \
		$(X86_64_BINARY) \
		-output $(UNIVERSAL_BINARY)
	@echo "✅ Universal Binary created"
	@lipo -info $(UNIVERSAL_BINARY)

# --- Generate app icon -------------------------------------------------------

icon:
	@echo "🎨 Generating AppIcon.icns..."
	@mkdir -p $(ICONSET_DIR)
	@bash scripts/create-icns.sh $(ICON_SVG) $(ICNS_OUTPUT) $(ICONSET_DIR)
	@echo "✅ Icon generated: $(ICNS_OUTPUT)"

# --- Assemble .app bundle ----------------------------------------------------

app-bundle: universal-binary icon
	@echo "📦 Assembling .app bundle..."
	@# Create directory structure
	@mkdir -p $(APP_MACOS)
	@mkdir -p $(APP_RESOURCES)
	@# Copy universal binary
	cp $(UNIVERSAL_BINARY) $(APP_MACOS)/$(APP_NAME)
	chmod +x $(APP_MACOS)/$(APP_NAME)
	@# Copy Info.plist
	cp $(INFO_PLIST) $(APP_CONTENTS)/Info.plist
	@# Copy app icon
	cp $(ICNS_OUTPUT) $(APP_RESOURCES)/AppIcon.icns
	@# Add icon reference to Info.plist if not present
	@/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" $(APP_CONTENTS)/Info.plist 2>/dev/null || \
		/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" $(APP_CONTENTS)/Info.plist
	@# Copy resource bundle (menubar icon)
	@if [ -d "$(ARM64_BUNDLE)" ]; then \
		cp -R $(ARM64_BUNDLE) $(APP_RESOURCES)/; \
		echo "  Copied resource bundle from arm64 build"; \
	elif [ -d "$(X86_64_BUNDLE)" ]; then \
		cp -R $(X86_64_BUNDLE) $(APP_RESOURCES)/; \
		echo "  Copied resource bundle from x86_64 build"; \
	fi
	@echo "✅ App bundle assembled: $(APP_BUNDLE)"

app: app-bundle
	@echo "✅ $(DISPLAY_NAME).app is ready at $(APP_BUNDLE)"

# --- Code signing ------------------------------------------------------------

sign: app-bundle
	@echo "🔏 Code signing with identity: $(SIGNING_IDENTITY)"
	@# Sign the main app bundle (nested resources are sealed automatically)
	@# Use --options runtime only with real Developer ID (required for notarization)
	@# Ad-hoc signing with hardened runtime causes LaunchServices to reject the app
	@if [ "$(SIGNING_IDENTITY)" = "-" ]; then \
		echo "  (ad-hoc signing — using minimal entitlements, no hardened runtime)"; \
		codesign --force --deep --sign "$(SIGNING_IDENTITY)" \
			--entitlements $(ENTITLEMENTS_ADHOC) \
			"$(APP_BUNDLE)"; \
	else \
		echo "  (Developer ID signing — hardened runtime + timestamp)"; \
		codesign --force --deep --sign "$(SIGNING_IDENTITY)" \
			--entitlements $(ENTITLEMENTS) \
			--options runtime \
			--timestamp \
			"$(APP_BUNDLE)"; \
	fi
	@echo "✅ Code signed"
	@codesign --verify --verbose "$(APP_BUNDLE)"

# --- Notarize .app (Apple Developer account required) -------------------------

notarize: check-notarize-credentials
	@echo "📝 Notarizing app bundle..."
	@# Create a ZIP for notarization submission (Apple requires ZIP or DMG)
	@echo "  Creating ZIP for submission..."
	ditto -c -k --keepParent "$(APP_BUNDLE)" "$(BUILD_DIR)/$(APP_NAME)-$(APP_VERSION)-notarize.zip"
	@echo "  Submitting to Apple notary service..."
	xcrun notarytool submit "$(BUILD_DIR)/$(APP_NAME)-$(APP_VERSION)-notarize.zip" \
		--apple-id "$(APPLE_ID)" \
		--team-id "$(TEAM_ID)" \
		--password "$(APP_PASSWORD)" \
		--wait
	@rm -f "$(BUILD_DIR)/$(APP_NAME)-$(APP_VERSION)-notarize.zip"
	@echo "✅ App notarized successfully"

# --- Notarize .dmg (Apple Developer account required) -------------------------

notarize-dmg: check-notarize-credentials
	@echo "📝 Notarizing disk image..."
	@echo "  Submitting DMG to Apple notary service..."
	xcrun notarytool submit "$(DMG_OUTPUT)" \
		--apple-id "$(APPLE_ID)" \
		--team-id "$(TEAM_ID)" \
		--password "$(APP_PASSWORD)" \
		--wait
	@echo "✅ DMG notarized successfully"

# --- Staple notarization ticket to .app ---------------------------------------

staple:
	@echo "📎 Stapling notarization ticket to app..."
	xcrun stapler staple "$(APP_BUNDLE)"
	@echo "✅ Ticket stapled to $(APP_BUNDLE)"

# --- Staple notarization ticket to .dmg ---------------------------------------

staple-dmg:
	@echo "📎 Stapling notarization ticket to DMG..."
	xcrun stapler staple "$(DMG_OUTPUT)"
	@echo "✅ Ticket stapled to $(DMG_OUTPUT)"

# --- Create .pkg installer ---------------------------------------------------

pkg: sign
	@echo "📀 Creating .pkg installer..."
	@mkdir -p $(PKG_DIR)
	@# Create component package (try with installer signing identity first)
	@if [ "$(INSTALLER_SIGNING_IDENTITY)" != "-" ]; then \
		echo "  Signing .pkg with: $(INSTALLER_SIGNING_IDENTITY)"; \
		pkgbuild \
			--root $(RELEASE_DIR) \
			--install-location /Applications \
			--identifier $(BUNDLE_ID) \
			--version $(APP_VERSION) \
			$(PKG_DIR)/$(APP_NAME)-component.pkg; \
		productbuild \
			--distribution $(DISTRIBUTION_XML) \
			--resources SupportFiles/installer-resources \
			--package-path $(PKG_DIR) \
			--version $(APP_VERSION) \
			--sign "$(INSTALLER_SIGNING_IDENTITY)" \
			$(PKG_OUTPUT); \
	else \
		echo "  (unsigned .pkg — no installer signing identity)"; \
		pkgbuild \
			--root $(RELEASE_DIR) \
			--install-location /Applications \
			--identifier $(BUNDLE_ID) \
			--version $(APP_VERSION) \
			$(PKG_DIR)/$(APP_NAME)-component.pkg; \
		productbuild \
			--distribution $(DISTRIBUTION_XML) \
			--resources SupportFiles/installer-resources \
			--package-path $(PKG_DIR) \
			--version $(APP_VERSION) \
			$(PKG_OUTPUT); \
	fi
	@echo "✅ Installer created: $(PKG_OUTPUT)"

# --- Create .dmg disk image --------------------------------------------------

dmg: sign
	@echo "💿 Creating .dmg disk image..."
	@mkdir -p $(DMG_DIR)
	@rm -rf $(DMG_DIR)/$(APP_NAME)
	@mkdir -p $(DMG_DIR)/$(APP_NAME)
	@# Copy app to staging area and strip extended attributes
	cp -R $(APP_BUNDLE) $(DMG_DIR)/$(APP_NAME)/
	xattr -cr $(DMG_DIR)/$(APP_NAME)/
	@# Create Applications symlink for drag-and-drop install
	ln -sf /Applications $(DMG_DIR)/$(APP_NAME)/Applications
	@# Create the DMG
	@rm -f $(DMG_OUTPUT)
	hdiutil create \
		-volname "$(DISPLAY_NAME)" \
		-srcfolder $(DMG_DIR)/$(APP_NAME) \
		-ov \
		-format UDZO \
		$(DMG_OUTPUT)
	@echo "✅ Disk image created: $(DMG_OUTPUT)"

# --- Store notarization credentials in keychain (one-time setup) --------------

store-credentials:
	@echo "🔐 Storing notarization credentials in keychain..."
	@echo "   This will prompt for your Apple ID password (app-specific password)."
	@echo ""
	@if [ -z "$(APPLE_ID)" ] || [ -z "$(TEAM_ID)" ]; then \
		echo "Usage: make store-credentials APPLE_ID=you@example.com TEAM_ID=XXXXXXXXXX"; \
		echo ""; \
		echo "After storing, use: APP_PASSWORD=@keychain:notarytool"; \
		exit 1; \
	fi
	xcrun notarytool store-credentials "notarytool" \
		--apple-id "$(APPLE_ID)" \
		--team-id "$(TEAM_ID)"
	@echo ""
	@echo "✅ Credentials stored! Now use: APP_PASSWORD=@keychain:notarytool"

# --- Clean -------------------------------------------------------------------

clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	rm -rf $(SPM_ARM64_BUILD)
	rm -rf $(SPM_X86_64_BUILD)
	@echo "✅ Clean complete"
