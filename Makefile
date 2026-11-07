include Config.mk

CONFIG ?= debug
APP := build/$(APP_NAME).app
INSTALLED := /Applications/$(APP_NAME).app
ICON := Resources/AppIcon.icon

.DEFAULT_GOAL := build
.PHONY: build run try-hook install uninstall icon test lint check verify smoke agent-check clean help

## build: Build, bundle, and ad-hoc sign the app (CONFIG=debug|release)
build: $(ICON)
	@Scripts/bundle.sh "$(CONFIG)" "$(APP_NAME)" "$(EXECUTABLE_NAME)" "$(BUNDLE_ID)" "$(MACOS_DEPLOYMENT_TARGET)"

## run: Build and launch the local app bundle
run: build
	@open "$(APP)"

## try-hook: Run the scheduler the way Bambu Studio does, on a sample G-code copy in build/
try-hook: build
	@Scripts/try-hook.sh "$(APP)" "$(EXECUTABLE_NAME)"

## install: Release-build and install the app in /Applications
install: CONFIG := release
install: build
	@echo "==> Installing $(INSTALLED)"
	@pkill -x "$(EXECUTABLE_NAME)" 2>/dev/null && sleep 1 || true
	@rm -rf "$(INSTALLED)"
	@ditto "$(APP)" "$(INSTALLED)"
	@codesign --verify --deep --strict --verbose=2 "$(INSTALLED)"
	@echo "Installed $(INSTALLED)"

## uninstall: Remove the installed app without deleting its user data
uninstall:
	@pkill -x "$(EXECUTABLE_NAME)" 2>/dev/null && sleep 1 || true
	@rm -rf "$(INSTALLED)"
	@echo "Removed $(INSTALLED)"

## icon: Regenerate the Liquid Glass icon source from ICON_SYMBOL and ICON_COLOR (needs glasur)
icon:
	@glasur generate --symbol "$(ICON_SYMBOL)" --color "$(ICON_COLOR)" --output "$(ICON)"

# Generated only when missing, so an icon refined in Icon Composer survives every build.
$(ICON):
	@$(MAKE) --no-print-directory icon

## test: Run the Swift Testing suite
test:
	@swift test

## lint: Check Swift formatting with the installed toolchain
lint:
	@swift format lint --recursive --strict Sources Tests

## check: Compile, test, and lint without launching
check: $(ICON)
	@swift build
	@$(MAKE) test
	@$(MAKE) lint

## verify: Validate the assembled bundle, metadata, icon, executable, and signature
verify: build
	@Scripts/verify-app.sh "$(APP)" "$(BUNDLE_ID)" "$(EXECUTABLE_NAME)"

## smoke: Launch briefly, prove the process stays alive, then quit it
smoke: build
	@Scripts/smoke-test.sh "$(APP)" "$(EXECUTABLE_NAME)"

## agent-check: Full non-destructive handoff gate for agents
agent-check: check verify smoke

## clean: Remove local build products
clean:
	@rm -rf build .build
	@echo "Cleaned"

## help: List available targets
help:
	@grep -h -E '^## ' $(MAKEFILE_LIST) | sed 's/^## /  /'
