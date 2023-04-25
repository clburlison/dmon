THEOS=$(PWD)/../theos
export THEOS

TARGET := iphone:14.4
ARCHS := arm64
DEBUG = 0

SDKVERSION = 14.5
export SYSROOT = $(THEOS)/sdks/sdks-master/iPhoneOS14.5.sdk

THEOS_DEVICE_IP = iphone

PACKAGE_NAME = com.github.clburlison.dmon
PACKAGE_VERSION = 0.0.10
HASH1 = $(shell shasum -a256 "packages/com.github.clburlison.dmon_$(PACKAGE_VERSION)_iphoneos-arm.deb" | cut -d " " -f1)
HASH2 = $(shell md5 "packages/com.github.clburlison.dmon_$(PACKAGE_VERSION)_iphoneos-arm.deb" | cut -d " " -f4)

# INSTALL_TARGET_PROCESSES = SpringBoard
TOOL_PATH = /usr/bin/dmon
DAEMON_PATH = LaunchDaemons/com.github.clburlison.dmon.plist
THEOS_LAYOUT_DIRECTORY = layout
TOOL_NAME = dmon
dmon_FILES = dmon.m
dmon_PRIVATE_FRAMEWORKS = SpringBoardServices
dmon_FRAMEWORKS = Foundation
# dmon_FRAMEWORKS = ManagedConfiguration
dmon_OBJ_FILES = ../theos/lib/libcrypto.a ../theos/lib/libcurl.a ../theos/lib/libnghttp2.a ../theos/lib/libssl.a
dmon_LDFLAGS = -lssl -lcurl -lz
dmon_CODESIGN_FLAGS = -SEntitlements.plist
LAUNCHDAEMON_PLIST = com.github.clburlison.dmon.plist
LAUNCHDAEMON_UPDATER_PLIST = com.github.clburlison.dmon-updater.plist
LAUNCHDAEMON_PATH = /Library/LaunchDaemons

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tool.mk

before-stage::
	find . -name ".DS_Store" -delete

before-package::
	mkdir -p $(THEOS_STAGING_DIR)/usr/bin
	mkdir -p $(THEOS_STAGING_DIR)$(LAUNCHDAEMON_PATH)
	cp $(LAUNCHDAEMON_PLIST) $(THEOS_STAGING_DIR)$(LAUNCHDAEMON_PATH)/
	cp $(LAUNCHDAEMON_UPDATER_PLIST) $(THEOS_STAGING_DIR)$(LAUNCHDAEMON_PATH)/
	cp dmon-updater $(THEOS_STAGING_DIR)/usr/bin/

after-package::
	make clean
	@echo "SHA-256: \`$(HASH1)\`"
	@echo "MD5: \`$(HASH2)\`"

upload:: all
	ssh iphone "rm /usr/bin/dmon" || true
	sleep 2
	scp .theos/obj/dmon iphone:/usr/bin/dmon
