# Fotoly Mobile — common Flutter workflows
# Usage: make help | make test | make run | ...

.DEFAULT_GOAL := help

# Prefer Flutter from PATH; fall back to ~/flutter if present.
FLUTTER ?= $(shell command -v flutter 2>/dev/null || echo $(HOME)/flutter/bin/flutter)
DART    ?= $(shell command -v dart 2>/dev/null || echo $(HOME)/flutter/bin/dart)

# Android / Java defaults used on this machine (override if needed).
export JAVA_HOME ?= $(HOME)/.jdks/temurin-17
export ANDROID_HOME ?= $(HOME)/Android/Sdk
export ANDROID_SDK_ROOT ?= $(ANDROID_HOME)
export PATH := $(JAVA_HOME)/bin:$(ANDROID_HOME)/cmdline-tools/latest/bin:$(ANDROID_HOME)/platform-tools:$(PATH)

# Optional device for run/build (e.g. chrome, linux, <device-id>)
DEVICE  ?=

# White-label pack: fotoly (default) or pixelfox.
FLAVOR  ?= fotoly

# Must match the flavor PUBLIC_DOMAIN (OAuth cookies are host-scoped).
# Run targets default to local API; APK builds omit this so the
# brand host is used (fotoly.eu).
API_BASE ?= http://localhost:8080
DART_DEFINES := --dart-define=FLAVOR=$(FLAVOR) --dart-define=PIXELFOX_API_BASE=$(API_BASE)
FLAVOR_FLAG := --flavor $(FLAVOR)

.PHONY: help get deps analyze test test-coverage check format fix \
	run run-chrome run-linux clean doctor devices build-apk build-apk-debug \
	build-web upgrade outdated

help: ## Show this help
	@echo "Fotoly Mobile — available targets:"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "Examples:"
	@echo "  make get && make check"
	@echo "  make run DEVICE=chrome"
	@echo "  make run-linux"
	@echo "  make build-apk-debug             # Fotoly phone APK"
	@echo "  make build-apk-debug FLAVOR=pixelfox"
	@echo "  make build-apk                   # release APK"
	@echo "  make test"

get deps: ## Install package dependencies (flutter pub get)
	$(FLUTTER) pub get

analyze: ## Static analysis (flutter analyze)
	$(FLUTTER) analyze

test: ## Run unit & widget tests
	$(FLUTTER) test

test-coverage: ## Run tests with coverage (coverage/lcov.info)
	$(FLUTTER) test --coverage

check: get analyze test ## Full gate: deps + analyze + test

format: ## Format Dart sources (dart format)
	$(DART) format lib test

fix: ## Apply dart fix --apply
	$(DART) fix --apply

run: ## Run app (optional: DEVICE=chrome|linux|<id> FLAVOR=pixelfox|fotoly)
	@echo "API: $(API_BASE)  FLAVOR: $(FLAVOR)"
	$(FLUTTER) run $(if $(DEVICE),-d $(DEVICE),) $(FLAVOR_FLAG) $(DART_DEFINES)

run-chrome: ## Run on Chrome (UI/auth only — no real folder pick/backup)
	@echo "Note: Chrome cannot pick local folders or scan the disk."
	@echo "      Use 'make run-linux' or a phone/emulator for Pick folder + backup."
	@echo "API: $(API_BASE)  FLAVOR: $(FLAVOR)"
	$(FLUTTER) run -d chrome $(FLAVOR_FLAG) $(DART_DEFINES)

run-linux: ## Run on Linux desktop against local API (http://localhost:8080)
	@if ! $(FLUTTER) devices 2>/dev/null | grep -qi 'linux'; then \
		echo "Linux device not available. Install desktop toolchain:"; \
		echo "  sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev"; \
		echo "Then: make doctor"; \
		exit 1; \
	fi
	@if ! pkg-config --exists libsecret-1 2>/dev/null; then \
		echo "Missing libsecret (needed by flutter_secure_storage):"; \
		echo "  sudo apt install libsecret-1-dev"; \
		exit 1; \
	fi
	@echo "API: $(API_BASE)  FLAVOR: $(FLAVOR)  (override with API_BASE=https://fotoly.eu)"
	$(FLUTTER) run -d linux $(FLAVOR_FLAG) $(DART_DEFINES)

devices: ## List available devices
	$(FLUTTER) devices

doctor: ## Flutter environment health check
	$(FLUTTER) doctor -v

build-apk: ## Build Android release APK for FLAVOR (default fotoly)
	$(FLUTTER) build apk $(FLAVOR_FLAG) --release --dart-define=FLAVOR=$(FLAVOR)
	@echo
	@echo "APK: build/app/outputs/flutter-apk/app-$(FLAVOR)-release.apk"
	@ls -lh build/app/outputs/flutter-apk/app-$(FLAVOR)-release.apk 2>/dev/null || true

build-apk-debug: ## Build debug APK for phone testing (FLAVOR=pixelfox|fotoly)
	$(FLUTTER) build apk $(FLAVOR_FLAG) --debug --dart-define=FLAVOR=$(FLAVOR)
	@cp -f build/app/outputs/flutter-apk/app-$(FLAVOR)-debug.apk $(FLAVOR)-debug.apk
	@cp -f build/app/outputs/flutter-apk/app-$(FLAVOR)-debug.apk "$(HOME)/Downloads/$(FLAVOR)-debug.apk" 2>/dev/null || true
	@echo
	@echo "APK: $(FLAVOR)-debug.apk  (and ~/Downloads/$(FLAVOR)-debug.apk if writable)"
	@ls -lh $(FLAVOR)-debug.apk

build-web: ## Build web release
	$(FLUTTER) build web --release

clean: ## Remove build artifacts
	$(FLUTTER) clean

upgrade: ## Upgrade packages within pubspec constraints
	$(FLUTTER) pub upgrade

outdated: ## Show outdated packages
	$(FLUTTER) pub outdated
