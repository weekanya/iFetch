#import "IFControlCenterBridge.h"

#import <objc/message.h>

BOOL IFCCOpenApplication(NSString *bundleIdentifier) {
    if (bundleIdentifier.length == 0) {
        return NO;
    }

    @try {
        Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
        if (workspaceClass == Nil) {
            return NO;
        }

        id workspace = [workspaceClass valueForKey:@"defaultWorkspace"];
        SEL selector = NSSelectorFromString(@"openApplicationWithBundleID:");
        if (workspace == nil || ![workspace respondsToSelector:selector]) {
            return NO;
        }

        return ((BOOL (*)(id, SEL, id))objc_msgSend)(workspace, selector, bundleIdentifier);
    } @catch (__unused NSException *exception) {
        return NO;
    }
}
