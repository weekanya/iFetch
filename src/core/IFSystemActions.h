#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^IFCommandCompletion)(int exitCode, int signalNumber, NSError * _Nullable error);

@interface IFSystemActions : NSObject

+ (void)runCommand:(NSString *)command
         arguments:(NSArray<NSString *> *)arguments
        completion:(IFCommandCompletion)completion;
+ (BOOL)terminateProcess:(pid_t)pid error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
