THEOS_PACKAGE_SCHEME = rootless
TARGET = iphone:clang:latest:15.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = IFetch

IFetch_FILES = main.m AppDelegate.m RootViewController.m
IFetch_FRAMEWORKS = UIKit CoreGraphics
IFetch_CODESIGN_FLAGS = -SEntitlements.plist
IFetch_LDFLAGS = -fuse-ld=lld
IFetch_CFLAGS = -fobjc-arc

include $(THEOS)/makefiles/application.mk