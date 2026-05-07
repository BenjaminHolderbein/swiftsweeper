APP_NAME = SwiftSweeper
BUILD_DIR = .build/debug
APP_PATH = $(BUILD_DIR)/$(APP_NAME).app
INSTALL_PATH = /Applications/$(APP_NAME).app
INFO_PLIST = Info.plist
ICON_SRC = icon_1024.png
ICONSET = AppIcon.iconset
ICNS = AppIcon.icns
SWIFT_FILES = $(shell find Sources -name "*.swift")
LSREGISTER = /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister

.PHONY: all build run clean icon install uninstall

all: build run

build:
	swift build

run: $(APP_PATH)
	@echo "Running $(APP_NAME)..."
	@open $(APP_PATH)

clean:
	swift package clean
	rm -rf $(BUILD_DIR) $(ICON_SRC) $(ICONSET) $(ICNS)

$(APP_PATH): $(SWIFT_FILES) $(INFO_PLIST) $(ICNS)
	swift build -c debug
	mkdir -p $(APP_PATH)/Contents/MacOS $(APP_PATH)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(APP_PATH)/Contents/MacOS/$(APP_NAME)
	cp $(INFO_PLIST) $(APP_PATH)/Contents/Info.plist
	cp $(ICNS) $(APP_PATH)/Contents/Resources/AppIcon.icns

$(ICON_SRC): make_icon.swift
	swift make_icon.swift $(ICON_SRC)

$(ICNS): $(ICON_SRC)
	rm -rf $(ICONSET) && mkdir $(ICONSET)
	sips -z 16   16   $(ICON_SRC) --out $(ICONSET)/icon_16x16.png > /dev/null
	sips -z 32   32   $(ICON_SRC) --out $(ICONSET)/icon_16x16@2x.png > /dev/null
	sips -z 32   32   $(ICON_SRC) --out $(ICONSET)/icon_32x32.png > /dev/null
	sips -z 64   64   $(ICON_SRC) --out $(ICONSET)/icon_32x32@2x.png > /dev/null
	sips -z 128  128  $(ICON_SRC) --out $(ICONSET)/icon_128x128.png > /dev/null
	sips -z 256  256  $(ICON_SRC) --out $(ICONSET)/icon_128x128@2x.png > /dev/null
	sips -z 256  256  $(ICON_SRC) --out $(ICONSET)/icon_256x256.png > /dev/null
	sips -z 512  512  $(ICON_SRC) --out $(ICONSET)/icon_256x256@2x.png > /dev/null
	sips -z 512  512  $(ICON_SRC) --out $(ICONSET)/icon_512x512.png > /dev/null
	cp $(ICON_SRC) $(ICONSET)/icon_512x512@2x.png
	iconutil -c icns $(ICONSET) -o $(ICNS)

icon: $(ICNS)

install: $(APP_PATH)
	@pkill -x $(APP_NAME) 2>/dev/null || true
	mkdir -p $(INSTALL_PATH)/Contents/MacOS $(INSTALL_PATH)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(INSTALL_PATH)/Contents/MacOS/$(APP_NAME)
	cp $(INFO_PLIST) $(INSTALL_PATH)/Contents/Info.plist
	cp $(ICNS) $(INSTALL_PATH)/Contents/Resources/AppIcon.icns
	touch $(INSTALL_PATH)
	$(LSREGISTER) -f $(INSTALL_PATH)
	@echo "Installed to $(INSTALL_PATH) — Spotlight should find it."

uninstall:
	@pkill -x $(APP_NAME) 2>/dev/null || true
	rm -rf $(INSTALL_PATH)
	$(LSREGISTER) -u $(INSTALL_PATH)
	@echo "Removed $(INSTALL_PATH)."
