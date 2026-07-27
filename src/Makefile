THEOS_PACKAGE_SCHEME ?= rootless
TARGET = iphone:clang:latest:14.0
ARCHS = arm64
STRIP = 0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = IFetch
TOOL_NAME = ifetch

IFetch_FILES = main.m AppDelegate.m RootViewController.m IFetchCore.m
IFetch_FRAMEWORKS = UIKit CoreGraphics SystemConfiguration
IFetch_CODESIGN_FLAGS = -SEntitlements.plist
IFetch_LDFLAGS = -fuse-ld=lld
IFetch_CFLAGS = -fobjc-arc

ifetch_FILES = cli/main.m IFetchCore.m
ifetch_FRAMEWORKS = Foundation SystemConfiguration
ifetch_CODESIGN_FLAGS = -SEntitlements.plist
ifetch_LDFLAGS = -fuse-ld=lld
ifetch_CFLAGS = -fobjc-arc

include $(THEOS)/makefiles/application.mk
include $(THEOS)/makefiles/tool.mk
