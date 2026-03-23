# ==============================================================================
# Mac AI Helper — Build & Packaging Makefile
# ==============================================================================
# Usage:
#   make dev                  — Build + launch locally (ad-hoc signed, sandbox)
#   make dev-signed           — Build + launch with App Store certs (local test)
#   make release              — Ad-hoc: clean → build → app → sign → pkg + dmg
#   make release-signed       — Developer ID: clean → build → sign → notarize → staple → pkg + dmg
#   make appstore             — Full App Store pipeline: build → sign → pkg → upload
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
BUNDLE_ID          := com.castloud.MacAIHelper

# Team credentials
TEAM_ID            ?= T2MHQ9ZQXG
APPLE_ID           ?= a.v.kazakou@gmail.com
APP_PASSWORD       ?= @keychain:notarytool

# Signing identities: use "-" for ad-hoc, or set to your Developer ID / App Store identity
# For ad-hoc local testing:
SIGNING_IDENTITY            ?= -
INSTALLER_SIGNING_IDENTITY  ?= $(SIGNING_IDENTITY)

# App Store signing identities (3rd Party Mac Developer)
APPSTORE_APP_IDENTITY       := 3rd Party Mac Developer Application: KAZAKOVA SOFTWARE CONSULTING LLC ($(TEAM_ID))
APPSTORE_INSTALLER_IDENTITY := 3rd Party Mac Developer Installer: KAZAKOVA SOFTWARE CONSULTING LLC ($(TEAM_ID))

# Provisioning profile
PROVISIONING_PROFILE := certs/MacAIHelper_AppStore_Distribution.provisionprofile

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
EXPORT_OPTIONS     := SupportFiles/ExportOptions.plist
STOREKIT_CONFIG    := SupportFiles/StoreKitConfiguration.storekit

# SPM build outputs (separate scratch paths to avoid cross-architecture conflicts)
SPM_ARM64_BUILD    := .build-arm64
SPM_X86_64_BUILD   := .build-x86_64
ARM64_BINARY       := $(SPM_ARM64_BUILD)/arm64-apple-macosx/release/$(APP_NAME)
X86_64_BINARY      := $(SPM_X86_64_BUILD)/x86_64-apple-macosx/release/$(APP_NAME)
UNIVERSAL_BINARY   := $(BUILD_DIR)/$(APP_NAME)-universal

# Read version from Info.plist (can be overridden via APP_VERSION=x.y.z)
APP_VERSION        ?= $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" $(INFO_PLIST) 2>/dev/null || echo "1.0.0")
BUILD_NUMBER       ?= $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleVersion" $(INFO_PLIST) 2>/dev/null || echo "1")

# Output artifacts
PKG_OUTPUT         := $(BUILD_DIR)/$(APP_NAME)-$(APP_VERSION).pkg
DMG_OUTPUT         := $(BUILD_DIR)/$(APP_NAME)-$(APP_VERSION).dmg
ICNS_OUTPUT        := $(BUILD_DIR)/AppIcon.icns
APPSTORE_PKG       := $(BUILD_DIR)/$(APP_NAME)-$(APP_VERSION)-appstore.pkg

# --- Phony targets -----------------------------------------------------------

.PHONY: all release release-signed app sign pkg dmg clean build-arm64 build-x86_64 \
        universal-binary icon app-bundle notarize notarize-dmg staple staple-dmg \
        check-identity check-notarize-credentials help dev dev-signed \
        appstore-icon appstore appstore-sign appstore-pkg appstore-upload \
        store-credentials

# --- Default target ----------------------------------------------------------

all: app
	@echo "✅ Build complete: $(APP_BUNDLE)"

# --- Help --------------------------------------------------------------------

help:
	@echo ""
	@echo "Mac AI Helper — Build Targets"
	@echo "=============================="
	@echo ""
	@echo "  Local Development:"
	@echo "  ──────────────────"
	@echo "  make dev               Build & launch locally (ad-hoc signed, sandbox)"
	@echo "  make dev-signed        Build & launch with App Store certs (local test)"
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
	@echo "  Mac App Store:"
	@echo "  ───────────────"
	@echo "  make appstore          Full pipeline: build → sign → pkg → upload"
	@echo "  make appstore-sign     Sign .app with App Store certificate"
	@echo "  make appstore-pkg      Create signed .pkg for App Store"
	@echo "  make appstore-upload   Upload .pkg to App Store Connect"
	@echo "  make appstore-icon     Generate 1024×1024 App Store icon"
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
	@echo "Variables:"
	@echo "  APP_VERSION                   Override version (default: from Info.plist)"
	@echo "  SIGNING_IDENTITY              Developer ID Application certificate name"
	@echo "  INSTALLER_SIGNING_IDENTITY    Developer ID Installer certificate name"
	@echo "  APPLE_ID                      Apple ID email (default: a.v.kazakou@gmail.com)"
	@echo "  TEAM_ID                       Apple Developer Team ID (default: T2MHQ9ZQXG)"
	@echo "  APP_PASSWORD                  App-specific password or @keychain:notarytool"
	@echo ""

# --- Validate signing identity -----------------------------------------------

check-identity:
	@echo "🔍 Checking available signing identities..."
	@echo ""
	@echo "Code signing identities:"
	@security find-identity -v -p codesigning || \
		echo "  ⚠️  No code signing certificates found"
	@echo ""
	@echo "All signing identities:"
	@security find-identity -v || \
		echo "  ⚠️  No signing certificates found"
	@echo ""
	@echo "App Store identities:"
	@security find-identity -v -p codesigning | grep "3rd Party Mac Developer" || \
		echo "  ⚠️  No '3rd Party Mac Developer' certificates found"
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

# ==============================================================================
# LOCAL DEVELOPMENT
# ==============================================================================

# --- Build & launch locally (ad-hoc signed, sandbox enabled) ------------------

dev: clean app-bundle
	@echo "🔏 Ad-hoc signing with sandbox entitlements..."
	codesign --force --deep --sign "-" \
		--entitlements $(ENTITLEMENTS_ADHOC) \
		"$(APP_BUNDLE)"
	@echo "✅ Ad-hoc signed"
	@codesign --verify --verbose "$(APP_BUNDLE)"
	@echo ""
	@echo "🚀 Launching $(DISPLAY_NAME)..."
	@open "$(APP_BUNDLE)"

# --- Build & launch with App Store certs (local test) -------------------------

dev-signed: clean app-bundle embed-profile
	@echo "🔏 Signing with App Store certificate..."
	@echo "   Identity: $(APPSTORE_APP_IDENTITY)"
	codesign --force --deep --sign "$(APPSTORE_APP_IDENTITY)" \
		--entitlements $(ENTITLEMENTS) \
		--timestamp \
		"$(APP_BUNDLE)"
	@echo "✅ App Store signed"
	@codesign --verify --verbose "$(APP_BUNDLE)"
	@echo ""
	@echo "🚀 Launching $(DISPLAY_NAME)..."
	@open "$(APP_BUNDLE)"

# --- Embed provisioning profile into .app bundle -----------------------------

embed-profile:
	@echo "📋 Embedding provisioning profile..."
	@if [ ! -f "$(PROVISIONING_PROFILE)" ]; then \
		echo "❌ Provisioning profile not found: $(PROVISIONING_PROFILE)"; \
		echo "   Download it from https://developer.apple.com/account/resources/profiles/list"; \
		exit 1; \
	fi
	@mkdir -p $(APP_CONTENTS)
	cp "$(PROVISIONING_PROFILE)" "$(APP_CONTENTS)/embedded.provisionprofile"
	@echo "✅ Profile embedded"

# ==============================================================================
# AD-HOC RELEASE
# ==============================================================================

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

# ==============================================================================
# DEVELOPER ID RELEASE (outside App Store)
# ==============================================================================

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

# ==============================================================================
# BUILD
# ==============================================================================

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
	@# Copy app resources directly into the bundle (no SPM resource bundle needed)
	cp SupportFiles/menubar-icon.png $(APP_RESOURCES)/menubar-icon.png
	@echo "  Copied menubar-icon.png to Resources"
	@# Copy SPM dependency resource bundles (e.g. KeyboardShortcuts localizations)
	@for bundle in $(SPM_ARM64_BUILD)/arm64-apple-macosx/release/*.bundle; do \
		if [ -d "$$bundle" ]; then \
			cp -R "$$bundle" $(APP_RESOURCES)/; \
			echo "  Copied $$(basename $$bundle) to Resources"; \
		fi; \
	done
	@echo "✅ App bundle assembled: $(APP_BUNDLE)"

app: app-bundle
	@echo "✅ $(DISPLAY_NAME).app is ready at $(APP_BUNDLE)"

# ==============================================================================
# CODE SIGNING
# ==============================================================================

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

# ==============================================================================
# NOTARIZATION (Developer ID only)
# ==============================================================================

notarize: check-notarize-credentials
	@echo "📝 Notarizing app bundle..."
	@# Create a ZIP for notarization submission (Apple requires ZIP or DMG)
	@echo "  Creating ZIP for submission..."
	ditto -c -k --keepParent "$(APP_BUNDLE)" "$(BUILD_DIR)/$(APP_NAME)-$(APP_VERSION)-notarize.zip"
	@echo "  Submitting to Apple notary service..."
	@if [ "$(APP_PASSWORD)" = "@keychain:notarytool" ]; then \
		xcrun notarytool submit "$(BUILD_DIR)/$(APP_NAME)-$(APP_VERSION)-notarize.zip" \
			--keychain-profile "notarytool" \
			--wait; \
	else \
		xcrun notarytool submit "$(BUILD_DIR)/$(APP_NAME)-$(APP_VERSION)-notarize.zip" \
			--apple-id "$(APPLE_ID)" \
			--team-id "$(TEAM_ID)" \
			--password "$(APP_PASSWORD)" \
			--wait; \
	fi
	@rm -f "$(BUILD_DIR)/$(APP_NAME)-$(APP_VERSION)-notarize.zip"
	@echo "✅ App notarized successfully"

notarize-dmg: check-notarize-credentials
	@echo "📝 Notarizing disk image..."
	@echo "  Submitting DMG to Apple notary service..."
	@if [ "$(APP_PASSWORD)" = "@keychain:notarytool" ]; then \
		xcrun notarytool submit "$(DMG_OUTPUT)" \
			--keychain-profile "notarytool" \
			--wait; \
	else \
		xcrun notarytool submit "$(DMG_OUTPUT)" \
			--apple-id "$(APPLE_ID)" \
			--team-id "$(TEAM_ID)" \
			--password "$(APP_PASSWORD)" \
			--wait; \
	fi
	@echo "✅ DMG notarized successfully"

staple:
	@echo "📎 Stapling notarization ticket to app..."
	xcrun stapler staple "$(APP_BUNDLE)"
	@echo "✅ Ticket stapled to $(APP_BUNDLE)"

staple-dmg:
	@echo "📎 Stapling notarization ticket to DMG..."
	xcrun stapler staple "$(DMG_OUTPUT)"
	@echo "✅ Ticket stapled to $(DMG_OUTPUT)"

# ==============================================================================
# PACKAGING (pkg & dmg)
# ==============================================================================

pkg: sign
	@echo "📀 Creating .pkg installer..."
	@mkdir -p $(PKG_DIR)
	@# Create component package
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

# ==============================================================================
# MAC APP STORE
# ==============================================================================

# --- Generate 1024×1024 App Store icon ----------------------------------------

appstore-icon: icon
	@echo "🎨 Generating 1024×1024 App Store icon..."
	@mkdir -p $(BUILD_DIR)
	@# Convert SVG to 1024x1024 PNG for App Store Connect upload
	@if command -v rsvg-convert >/dev/null 2>&1; then \
		rsvg-convert -w 1024 -h 1024 $(ICON_SVG) -o $(BUILD_DIR)/AppStoreIcon.png; \
	elif command -v sips >/dev/null 2>&1 && [ -f "$(ICONSET_DIR)/icon_512x512@2x.png" ]; then \
		cp "$(ICONSET_DIR)/icon_512x512@2x.png" $(BUILD_DIR)/AppStoreIcon.png; \
	else \
		echo "⚠️  Install librsvg (brew install librsvg) for SVG→PNG conversion"; \
		echo "   Or manually export icon.svg as 1024x1024 PNG to $(BUILD_DIR)/AppStoreIcon.png"; \
	fi
	@echo "✅ App Store icon: $(BUILD_DIR)/AppStoreIcon.png"

# --- Sign .app with App Store certificate ------------------------------------

appstore-sign: app-bundle embed-profile
	@echo "🔏 Signing for Mac App Store..."
	@echo "   Identity: $(APPSTORE_APP_IDENTITY)"
	@# Sign the app bundle with App Store entitlements
	codesign --force --deep --sign "$(APPSTORE_APP_IDENTITY)" \
		--entitlements $(ENTITLEMENTS) \
		--timestamp \
		"$(APP_BUNDLE)"
	@echo "✅ App Store signed"
	@codesign -dvv "$(APP_BUNDLE)" 2>&1 | grep -E "(Authority|TeamIdentifier|Identifier)"
	@echo ""

# --- Create signed .pkg for App Store submission -----------------------------

appstore-pkg: appstore-sign
	@echo "📀 Creating App Store .pkg..."
	@mkdir -p $(PKG_DIR)
	@# productbuild creates installer pkg signed with Installer certificate
	productbuild \
		--component "$(APP_BUNDLE)" /Applications \
		--sign "$(APPSTORE_INSTALLER_IDENTITY)" \
		--timestamp \
		"$(APPSTORE_PKG)"
	@echo "✅ App Store .pkg created: $(APPSTORE_PKG)"
	@echo ""
	@# Verify the pkg
	pkgutil --check-signature "$(APPSTORE_PKG)" 2>&1 | head -5
	@echo ""

# --- Upload .pkg to App Store Connect ----------------------------------------

appstore-upload: appstore-pkg
	@echo "🚀 Uploading to App Store Connect..."
	@if [ -z "$(APP_PASSWORD)" ]; then \
		echo "❌ APP_PASSWORD is required for upload"; \
		echo "   Create an app-specific password at https://appleid.apple.com"; \
		echo "   Usage: make appstore-upload APP_PASSWORD=xxxx-xxxx-xxxx-xxxx"; \
		echo ""; \
		echo "   Or use Transporter.app to manually upload:"; \
		echo "   $(APPSTORE_PKG)"; \
		exit 1; \
	fi
	@if [ "$(APP_PASSWORD)" = "@keychain:notarytool" ]; then \
		echo "  Using keychain credentials (profile: notarytool)"; \
		xcrun altool --upload-app \
			--type macos \
			--file "$(APPSTORE_PKG)" \
			--apple-id "$(APPLE_ID)" \
			--team-id "$(TEAM_ID)" \
			--password "$(APP_PASSWORD)"; \
	else \
		xcrun altool --upload-app \
			--type macos \
			--file "$(APPSTORE_PKG)" \
			--apple-id "$(APPLE_ID)" \
			--team-id "$(TEAM_ID)" \
			--password "$(APP_PASSWORD)"; \
	fi
	@echo "✅ Uploaded to App Store Connect"

# --- Full App Store pipeline --------------------------------------------------

appstore: clean appstore-icon appstore-pkg
	@echo ""
	@echo "🎉 App Store build complete!"
	@echo "   App:     $(APP_BUNDLE)"
	@echo "   Package: $(APPSTORE_PKG)"
	@echo "   Icon:    $(BUILD_DIR)/AppStoreIcon.png"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Upload via Transporter.app or: make appstore-upload APP_PASSWORD=xxxx-xxxx-xxxx-xxxx"
	@echo "  2. Go to App Store Connect to submit for review"
	@echo ""

# ==============================================================================
# CREDENTIALS
# ==============================================================================

# --- Store notarization credentials in keychain (one-time setup) --------------

store-credentials:
	@echo "🔐 Storing notarization credentials in keychain..."
	@echo "   This will prompt for your Apple ID password (app-specific password)."
	@echo ""
	xcrun notarytool store-credentials "notarytool" \
		--apple-id "$(APPLE_ID)" \
		--team-id "$(TEAM_ID)"
	@echo ""
	@echo "✅ Credentials stored! Now use: APP_PASSWORD=@keychain:notarytool"

# ==============================================================================
# CLEAN
# ==============================================================================

clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	rm -rf $(SPM_ARM64_BUILD)
	rm -rf $(SPM_X86_64_BUILD)
	@echo "✅ Clean complete"
