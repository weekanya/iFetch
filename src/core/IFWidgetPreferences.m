#import "IFWidgetPreferences.h"

#import <sys/stat.h>

static NSString *IFWidgetGlobalDirectory(void) {
    return @"/var/mobile/Library/Application Support/iFetch";
}

static NSString *IFWidgetGlobalPath(void) {
    return [IFWidgetGlobalDirectory() stringByAppendingPathComponent:@"widget.plist"];
}

static NSString *IFWidgetLegacyPath(void) {
    return @"/var/mobile/Library/Preferences/com.wee1ka.ifetch.widget.plist";
}

static NSString *IFWidgetPluginContainer(void) {
    NSString *base = @"/var/mobile/Containers/Data/PluginKitPlugin";
    NSFileManager *manager = NSFileManager.defaultManager;
    for (NSString *name in [manager contentsOfDirectoryAtPath:base error:nil]) {
        NSString *candidate = [base stringByAppendingPathComponent:name];
        NSString *metadataPath = [candidate stringByAppendingPathComponent:
            @".com.apple.mobile_container_manager.metadata.plist"];
        NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
        if ([metadata[@"MCMMetadataIdentifier"] isEqualToString:@"com.wee1ka.ifetch.widgets"]) {
            return candidate;
        }
    }
    return nil;
}

static NSString *IFWidgetPluginPath(void) {
    NSString *container = IFWidgetPluginContainer();
    if (container.length == 0) {
        return nil;
    }
    return [container stringByAppendingPathComponent:@"Library/Application Support/iFetch/widget.plist"];
}

static NSDictionary *IFWidgetDictionaryAtPath(NSString *path) {
    NSDictionary *dictionary = path.length > 0
        ? [NSDictionary dictionaryWithContentsOfFile:path] : nil;
    return [dictionary isKindOfClass:[NSDictionary class]] ? dictionary : nil;
}

static BOOL IFWidgetWriteAtPath(NSDictionary *preferences, NSString *path, NSError **error) {
    if (path.length == 0) {
        return NO;
    }
    NSFileManager *manager = NSFileManager.defaultManager;
    NSString *directory = path.stringByDeletingLastPathComponent;
    if (![manager createDirectoryAtPath:directory withIntermediateDirectories:YES
                             attributes:@{NSFilePosixPermissions: @0755} error:error]) {
        return NO;
    }
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:preferences
                                                              format:NSPropertyListBinaryFormat_v1_0
                                                             options:0 error:error];
    if (data == nil || ![data writeToFile:path options:NSDataWritingAtomic error:error]) {
        return NO;
    }
    chmod(path.fileSystemRepresentation, 0644);
    return YES;
}

NSDictionary<NSString *, id> *IFWidgetPreferencesRead(void) {
    NSDictionary *preferences = IFWidgetDictionaryAtPath(IFWidgetPluginPath());
    if (preferences == nil) {
        preferences = IFWidgetDictionaryAtPath(IFWidgetGlobalPath());
    }
    if (preferences == nil) {
        preferences = IFWidgetDictionaryAtPath(IFWidgetLegacyPath());
    }
    return preferences ?: @{};
}

BOOL IFWidgetPreferencesWrite(NSDictionary<NSString *, id> *preferences, NSError **error) {
    NSMutableDictionary *values = [preferences mutableCopy] ?: [NSMutableDictionary dictionary];
    values[@"revision"] = @((long long)(NSDate.date.timeIntervalSince1970 * 1000.0));
    NSError *globalError = nil;
    BOOL globalSaved = IFWidgetWriteAtPath(values, IFWidgetGlobalPath(), &globalError);
    NSString *pluginPath = IFWidgetPluginPath();
    NSError *pluginError = nil;
    BOOL pluginSaved = pluginPath.length == 0 ||
        IFWidgetWriteAtPath(values, pluginPath, &pluginError);
    [values writeToFile:IFWidgetLegacyPath() atomically:YES];
    chmod(IFWidgetLegacyPath().fileSystemRepresentation, 0644);
    if ((!globalSaved || !pluginSaved) && error != NULL) {
        *error = pluginError ?: globalError;
    }
    return globalSaved && pluginSaved;
}
