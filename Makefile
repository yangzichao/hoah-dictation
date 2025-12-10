# Define a directory for dependencies in the user's home folder
DEPS_DIR := $(HOME)/HoAh-Dependencies
WHISPER_CPP_DIR := $(DEPS_DIR)/whisper.cpp
FRAMEWORK_PATH := $(WHISPER_CPP_DIR)/build-apple/whisper.xcframework

.PHONY: all clean whisper setup build check healthcheck help dev run reset-onboarding archive-mas export-mas check-mas
DMG_VERSION ?= 3.0.0
MAS_VERSION = 3.1.7

# Default target
all: check build

# Development workflow
dev: build run

# Prerequisites
check:
	@echo "Checking prerequisites..."
	@command -v git >/dev/null 2>&1 || { echo "git is not installed"; exit 1; }
	@command -v xcodebuild >/dev/null 2>&1 || { echo "xcodebuild is not installed (need Xcode)"; exit 1; }
	@command -v swift >/dev/null 2>&1 || { echo "swift is not installed"; exit 1; }
	@echo "Prerequisites OK"

healthcheck: check

# Build process
whisper:
	@mkdir -p $(DEPS_DIR)
	@if [ ! -d "$(FRAMEWORK_PATH)" ]; then \
		echo "Building whisper.xcframework in $(DEPS_DIR)..."; \
		if [ ! -d "$(WHISPER_CPP_DIR)" ]; then \
			git clone https://github.com/ggerganov/whisper.cpp.git $(WHISPER_CPP_DIR); \
		else \
			(cd $(WHISPER_CPP_DIR) && git pull); \
		fi; \
		cd $(WHISPER_CPP_DIR) && ./build-xcframework.sh; \
	else \
		echo "whisper.xcframework already built in $(DEPS_DIR), skipping build"; \
	fi

setup: whisper
	@echo "Whisper framework is ready at $(FRAMEWORK_PATH)"
	@echo "Please ensure your Xcode project references the framework from this new location."

BUILD_DIR := $(PWD)/build/DerivedData

build: setup
	xcodebuild -scheme HoAh -configuration Debug \
		CODE_SIGN_IDENTITY="" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" \
		ARCHS=arm64 ONLY_ACTIVE_ARCH=YES SWIFT_DISABLE_EXPLICIT_MODULES=YES ENABLE_HARDENED_RUNTIME=NO \
		SWIFT_ACTIVE_COMPILATION_CONDITIONS="DEBUG" \
		-derivedDataPath $(BUILD_DIR)

# Run application
run:
	@APP_PATH="$(BUILD_DIR)/Build/Products/Debug/HoAh.app"; \
	if [ -d "$$APP_PATH" ]; then \
		echo "Launching: $$APP_PATH"; \
		open "$$APP_PATH"; \
	else \
		echo "HoAh.app not found at $$APP_PATH. Run 'make build' first."; \
		exit 1; \
	fi

# Cleanup
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(DEPS_DIR)
	@echo "Clean complete"

# Reset onboarding flow so the app behaves like first launch
reset-onboarding:
	@echo "Resetting onboarding state for HoAh (bundle id: com.yangzichao.hoah)..."
	@defaults delete com.yangzichao.hoah HasCompletedOnboarding || echo "No existing onboarding flag to delete."
	@echo "Next launch will show the full onboarding flow again."

# Build signed DMG with Applications link (uses Release build)
dmg:
	@bash scripts/packaging/build_dmg.sh $(DMG_VERSION)

# Build, sign, notarize, and staple DMG (requires SIGN_IDENTITY/TEAM_ID and notary credentials)
release-dmg:
	@bash scripts/packaging/sign_and_notarize.sh $(DMG_VERSION)

# Mac App Store targets
archive-mas:
	@echo "Building Mac App Store archive..."
	@bash scripts/packaging/build_mas_archive.sh $(MAS_VERSION)

export-mas:
	@echo "Exporting Mac App Store package..."
	@bash scripts/packaging/export_mas.sh

check-mas:
	@echo "Checking App Store configuration..."
	@bash scripts/packaging/check_setup.sh

# Help
help:
	@echo "Available targets:"
	@echo ""
	@echo "Development:"
	@echo "  check/healthcheck  Check if required CLI tools are installed"
	@echo "  whisper            Clone and build whisper.cpp XCFramework"
	@echo "  setup              Copy whisper XCFramework to HoAh project"
	@echo "  build              Build the HoAh Xcode project"
	@echo "  run                Launch the built HoAh app"
	@echo "  dev                Build and run the app (for development)"
	@echo "  reset-onboarding   Clear onboarding flag so next launch shows first-time experience"
	@echo "  clean              Remove build artifacts"
	@echo ""
	@echo "App Store:"
	@echo "  check-mas          Check App Store configuration and certificates"
	@echo "  archive-mas        Build Mac App Store archive"
	@echo "  export-mas         Export Mac App Store package (.pkg)"
	@echo ""
	@echo "Other:"
	@echo "  all                Run full build process (default)"
	@echo "  help               Show this help message"
	@echo ""
	@echo "For App Store submission guide, see: docs/QUICK_START_APP_STORE.md"
