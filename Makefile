# ==============================================================================
# Mac AI Helper — Build & Packaging Makefile
# ==============================================================================
# Usage:
#   make dev                  — Build + launch locally (App Store signed)
#   make appstore             — Full App Store pipeline: build → sign → pkg → upload
#   make appstore-sign        — Sign .app with App Store certificate
#   make appstore-pkg         — Create signed .pkg for App Store
#   make appstore-upload      — Upload .pkg to App Store Connect
#   make app                  — Build Universal .app bundle only
#   make clean                — Remove all build artifacts
#
# Variables:
#   APP_VERSION               — Override version string (reads from Info.plist by default)
#   APPLE_ID                  — Apple ID email for App Store uploads
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

# App Store signing identities (3rd Party Mac Developer)
APPSTORE_APP_IDENTITY       := 3rd Party Mac Developer Application: KAZAKOVA SOFTWARE CONSULTING LLC ($(TEAM_ID))
APPSTORE_INSTALLER_IDENTITY := 3rd Party Mac Developer Installer: KAZAKOVA SOFTWARE CONSULTING LLC ($(TEAM_ID))

# Provisioning profile
PROVISIONING_PROFILE := certs/MacAIHelper_AppStore_Distribution.provisionprofile

# Directories
BUILD_DIR          := build
RELEASE_DIR        := $(BUILD_DIR)/release
PKG_DIR            := $(BUILD_DIR)/pkg
ICONSET_DIR        := $(BUILD_DIR)/AppIcon.iconset

# App bundle paths
APP_BUNDLE         := $(RELEASE_DIR)/$(APP_NAME).app
APP_CONTENTS       := $(APP_BUNDLE)/Contents
APP_MACOS          := $(APP_CONTENTS)/MacOS
APP_RESOURCES      := $(APP_CONTENTS)/Resources

# Source files
INFO_PLIST         := SupportFiles/Info.plist
ENTITLEMENTS       := SupportFiles/MacAIHelper.entitlements
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
APPSTORE_PKG       := $(BUILD_DIR)/$(APP_NAME)-$(APP_VERSION)-appstore.pkg
ICNS_OUTPUT        := $(BUILD_DIR)/AppIcon.icns

# --- Phony targets -----------------------------------------------------------

.PHONY: all app clean build-arm64 build-x86_64 \
        universal-binary icon app-bundle embed-profile \
        check-identity help dev \
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
	@echo "  make dev               Build & launch locally (App Store signed)"
	@echo ""
	@echo "  Build:"
	@echo "  ──────"
	@echo "  make app               Build Universal .app bundle"
	@echo "  make build-arm64       Build release binary for Apple Silicon"
	@echo "  make build-x86_64      Build release binary for Intel"
	@echo "  make universal-binary  Combine into Universal Binary"
	@echo "  make icon              Generate AppIcon.icns from SVG"
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
	@echo "  make check-identity    Verify signing identities are available"
	@echo "  make store-credentials Store notarization credentials in keychain"
	@echo "  make clean             Remove all build artifacts"
	@echo ""
	@echo "Variables:"
	@echo "  APP_VERSION                   Override version (default: from Info.plist)"
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
	@echo "App Store identities:"
	@security find-identity -v -p codesigning | grep "3rd Party Mac Developer" || \
		echo "  ⚠️  No '3rd Party Mac Developer' certificates found"
	@echo ""

# ==============================================================================
# LOCAL DEVELOPMENT
# ==============================================================================

# --- Build & launch locally (App Store signed) --------------------------------

dev: clean app-bundle embed-profile
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
	@echo "🔐 Storing credentials in keychain..."
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
