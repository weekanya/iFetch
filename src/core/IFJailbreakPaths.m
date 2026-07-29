#import "IFJailbreakPaths.h"

#if __has_include(<roothide.h>)
#import <roothide.h>
#define IF_HAS_ROOTHIDE 1
#else
#define IF_HAS_ROOTHIDE 0
#endif

static NSString *IFNormalizedBootstrapPath(NSString *path) {
    if (path.length == 0) {
        return @"/";
    }
    return [path hasPrefix:@"/"] ? path : [@"/" stringByAppendingString:path];
}

BOOL IFRootHideRuntime(void) {
#if IF_HAS_ROOTHIDE
    return jbrand() != 0;
#else
    return NO;
#endif
}

NSString *IFBootstrapPath(NSString *path) {
    NSString *normalized = IFNormalizedBootstrapPath(path);
#if IF_HAS_ROOTHIDE
    NSString *resolved = jbroot(normalized);
    return resolved.length > 0 ? resolved : normalized;
#else
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb"]) {
        return [normalized isEqualToString:@"/"]
            ? @"/var/jb"
            : [@"/var/jb" stringByAppendingString:normalized];
    }
    return normalized;
#endif
}

NSString *IFBootstrapRootPath(void) {
    if (IFRootHideRuntime()) {
        return [IFBootstrapPath(@"/") stringByStandardizingPath];
    }
    return [[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb"] ? @"/var/jb" : @"";
}
