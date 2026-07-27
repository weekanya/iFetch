THEOS_PACKAGE_SCHEME ?= rootless
THEOS_PACKAGE_DIR = ../packages
TARGET = iphone:clang:latest:14.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = SpringBoard
# В Linux-окружении используется GNU strip, который не понимает Mach-O.
STRIP = 0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = IFetch
TOOL_NAME = ifetch
BUNDLE_NAME = IFetchModule

IFetch_FILES = \
	app/main.m \
	app/AppDelegate.m \
	app/RootViewController.m \
	app/DiagnosticsViewController.m \
	core/IFetchCore.m \
	core/IFDiagnostics.m
IFetch_FRAMEWORKS = UIKit CoreGraphics SystemConfiguration CoreLocation NetworkExtension
IFetch_RESOURCE_DIRS = resources
IFetch_CODESIGN_FLAGS = -Spackaging/Entitlements.plist
IFetch_LDFLAGS = -fuse-ld=lld
IFetch_CFLAGS = -fobjc-arc

ifetch_FILES = \
	cli/main.m \
	core/IFetchCore.m \
	core/IFDiagnostics.m
ifetch_FRAMEWORKS = Foundation SystemConfiguration NetworkExtension
ifetch_CODESIGN_FLAGS = -Spackaging/Entitlements.plist
ifetch_LDFLAGS = -fuse-ld=lld
ifetch_CFLAGS = -fobjc-arc

IFetchModule_FILES = \
	control-center/IFetchModule.m \
	core/IFetchCore.m \
	core/IFDiagnostics.m
IFetchModule_FRAMEWORKS = UIKit Foundation SystemConfiguration NetworkExtension
IFetchModule_PRIVATE_FRAMEWORKS = ControlCenterUIKit
IFetchModule_INSTALL_PATH = /Library/ControlCenter/Bundles
IFetchModule_CFLAGS = -fobjc-arc
IFetchModule_LDFLAGS = -fuse-ld=lld
IFetchModule_BUNDLE_EXTENSION = bundle
IFetchModule_BUNDLE_RESOURCE_DIRS = packaging/ControlCenterModule

include $(THEOS)/makefiles/application.mk
include $(THEOS)/makefiles/tool.mk
include $(THEOS_MAKE_PATH)/bundle.mk
