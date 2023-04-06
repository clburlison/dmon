THEOS=$(PWD)/theos
export THEOS

TARGET := iphone:14.4
ARCHS := arm64
DEBUG = 0

SDKVERSION = 14.5
export SYSROOT = $(THEOS)/sdks/sdks-master/iPhoneOS14.5.sdk

include $(THEOS)/makefiles/common.mk

# INSTALL_TARGET_PROCESSES = SpringBoard
TOOL_NAME = dmon
dmon_FILES = dmon.m
dmon_PRIVATE_FRAMEWORKS = SpringBoardServices
# dmon_FRAMEWORKS = ManagedConfiguration
dmon_OBJ_FILES = ./theos/lib/libcrypto.a ./theos/lib/libcurl.a ./theos/lib/libnghttp2.a ./theos/lib/libssl.a
dmon_LDFLAGS = -lssl -lcurl -lz
dmon_CODESIGN_FLAGS = -SEntitlements.plist

include $(THEOS_MAKE_PATH)/tool.mk

all::
	mkdir -p ../src/usr/bin
	/bin/cp .theos/obj/dmon ../src/usr/bin
