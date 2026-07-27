THEOS_PACKAGE_SCHEME ?= rootless
TARGET = iphone:clang:latest:14.0
ARCHS = arm64
# В Linux-окружении используется GNU strip, который не понимает Mach-O.
STRIP = 0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = IFetch
TOOL_NAME = ifetch
BUNDLE_NAME = IFetchModule

IFetch_FILES = main.m AppDelegate.m RootViewController.m DiagnosticsViewController.m IFetchCore.m IFDiagnostics.m
IFetch_FRAMEWORKS = UIKit CoreGraphics SystemConfiguration
IFetch_CODESIGN_FLAGS = -SEntitlements.plist
IFetch_LDFLAGS = -fuse-ld=lld
IFetch_CFLAGS = -fobjc-arc

ifetch_FILES = cli/main.m IFetchCore.m IFDiagnostics.m
ifetch_FRAMEWORKS = Foundation SystemConfiguration
ifetch_CODESIGN_FLAGS = -SEntitlements.plist
ifetch_LDFLAGS = -fuse-ld=lld
ifetch_CFLAGS = -fobjc-arc

IFetchModule_FILES = CCModule/IFetchModule.m IFetchCore.m IFDiagnostics.m
IFetchModule_FRAMEWORKS = UIKit Foundation SystemConfiguration
IFetchModule_PRIVATE_FRAMEWORKS = ControlCenterUIKit
IFetchModule_INSTALL_PATH = /Library/ControlCenter/Bundles
IFetchModule_CFLAGS = -fobjc-arc
IFetchModule_LDFLAGS = -fuse-ld=lld
IFetchModule_BUNDLE_EXTENSION = bundle
IFetchModule_BUNDLE_RESOURCE_DIRS = IFetchModule

include $(THEOS)/makefiles/application.mk
include $(THEOS)/makefiles/tool.mk
include $(THEOS_MAKE_PATH)/bundle.mk
