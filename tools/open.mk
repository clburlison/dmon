TARGET := iphone:14.4:10.0
ARCHS := arm64
DEBUG = 0

SDKVERSION = 14.5
export SYSROOT = $(THEOS)/sdks/sdks-master/iPhoneOS14.5.sdk

include $(THEOS)/makefiles/common.mk

TOOL_NAME = open
open_FILES = open.m
open_PRIVATE_FRAMEWORKS = SpringBoardServices
open_CODESIGN_FLAGS = -SEntitlements.plist

include $(THEOS_MAKE_PATH)/tool.mk

all::
	mkdir -p ../src/usr/bin
	/bin/cp .theos/obj/open ../src/usr/bin
