#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSDictionary<NSString *, id> *IFWidgetPreferencesRead(void);
FOUNDATION_EXPORT BOOL IFWidgetPreferencesWrite(NSDictionary<NSString *, id> *preferences,
                                                NSError **error);

NS_ASSUME_NONNULL_END
