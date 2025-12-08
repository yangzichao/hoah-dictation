# Define a directory for dependencies in the user's home folder
DEPS_DIR := $(HOME)/HoAh-Dependencies
WHISPER_CPP_DIR := $(DEPS_DIR)/whisper.cpp
FRAMEWORK_PATH := $(WHISPER_CPP_DIR)/build-apple/whisper.xcframework

.PHONY: all clean whisper setup build check healthcheck help dev run reset-onboarding
DMG_VERSION ?= 3.0.0

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
		CODE_SIGN_IDENTITY="-" ARCHS=arm64 ONLY_ACTIVE_ARCH=YES SWIFT_DISABLE_EXPLICIT_MODULES=YES \
		-derivedDataPath $(BUILD_DIR)

# Run application
run:
	@echo "Looking for HoAh.app..."
	@APP_PATH=$$(find "$(BUILD_DIR)" "$$HOME/Library/Developer/Xcode/DerivedData" -name "HoAh.app" -type d | head -1) && \
	if [ -n "$$APP_PATH" ]; then \
		echo "Found app at: $$APP_PATH"; \
		open "$$APP_PATH"; \
	else \
		echo "HoAh.app not found. Please run 'make build' first."; \
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

# Help
help:
	@echo "Available targets:"
	@echo "  check/healthcheck  Check if required CLI tools are installed"
	@echo "  whisper            Clone and build whisper.cpp XCFramework"
	@echo "  setup              Copy whisper XCFramework to HoAh project"
	@echo "  build              Build the HoAh Xcode project"
	@echo "  run                Launch the built HoAh app"
	@echo "  dev                Build and run the app (for development)"
	@echo "  reset-onboarding   Clear onboarding flag so next launch shows first-time experience"
	@echo "  all                Run full build process (default)"
	@echo "  clean              Remove build artifacts"
	@echo "  help               Show this help message"
