THEOS_PACKAGE_SCHEME ?= rootless
THEOS_PACKAGE_DIR = ../packages
TARGET = iphone:clang:latest:14.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = SpringBoard
STRIP = 0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = IFetch
TOOL_NAME = ifetch
BUNDLE_NAME = IFetchModule
APPEX_NAME = IFetchWidgets

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
IFetch_CFLAGS = -fobjc-arc

ifetch_FILES = \
	cli/main.m \
	core/IFetchCore.m \
	core/IFDiagnostics.m
ifetch_FRAMEWORKS = Foundation SystemConfiguration NetworkExtension
ifetch_CODESIGN_FLAGS = -Spackaging/Entitlements.plist
ifetch_CFLAGS = -fobjc-arc

IFetchModule_FILES = \
	control-center/IFetchModule.m \
	core/IFetchCore.m \
	core/IFDiagnostics.m
IFetchModule_FRAMEWORKS = UIKit Foundation SystemConfiguration NetworkExtension
IFetchModule_PRIVATE_FRAMEWORKS = ControlCenterUIKit
IFetchModule_INSTALL_PATH = /Library/ControlCenter/Bundles
IFetchModule_CFLAGS = -fobjc-arc
IFetchModule_BUNDLE_EXTENSION = bundle
IFetchModule_BUNDLE_RESOURCE_DIRS = packaging/ControlCenterModule

IFetchWidgets_FILES = \
	widgets/IFetchWidgets.swift \
	widgets/IFWidgetMetrics.m
IFetchWidgets_FRAMEWORKS = SwiftUI WidgetKit UIKit Foundation
IFetchWidgets_INSTALL_PATH = /Applications/IFetch.app/PlugIns
IFetchWidgets_RESOURCE_DIRS = packaging/WidgetExtension
IFetchWidgets_SWIFT_BRIDGING_HEADER = widgets/IFetchWidgets-Bridging-Header.h
IFetchWidgets_CODESIGN_FLAGS = -Spackaging/WidgetEntitlements.plist
IFetchWidgets_CFLAGS = -fobjc-arc

ifeq ($(THEOS_PLATFORM_NAME),linux)
IFetch_LDFLAGS = -fuse-ld=lld
ifetch_LDFLAGS = -fuse-ld=lld
IFetchModule_LDFLAGS = -fuse-ld=lld
IFetchWidgets_LDFLAGS = -fuse-ld=lld
endif

include $(THEOS)/makefiles/application.mk
include $(THEOS)/makefiles/tool.mk
include $(THEOS_MAKE_PATH)/bundle.mk
include $(THEOS_MAKE_PATH)/appex.mk
