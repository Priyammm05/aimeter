PROJECT  := AIMeter.xcodeproj
SCHEME   := AIMeter
BUILD_DIR := $(CURDIR)/build

.PHONY: build demo clean

## Build the debug binary into ./build/
build:
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-destination 'platform=macOS' \
		CONFIGURATION_BUILD_DIR=$(BUILD_DIR) \
		build | xcpretty 2>/dev/null || xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-destination 'platform=macOS' \
		CONFIGURATION_BUILD_DIR=$(BUILD_DIR) \
		build

## Build then launch interactive demo mode
demo: build
	@bash demo.sh

## Remove local build artefacts
clean:
	rm -rf $(BUILD_DIR)
