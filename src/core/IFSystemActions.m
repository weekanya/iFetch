#import "IFSystemActions.h"

#import "IFetchCore.h"

#import <errno.h>
#import <signal.h>
#import <spawn.h>
#import <string.h>
#import <sys/wait.h>
#import <unistd.h>

extern char **environ;

static NSError *IFActionError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:@"com.wee1ka.ifetch.actions"
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

@implementation IFSystemActions

+ (NSArray<NSString *> *)pathsForCommand:(NSString *)command {
    return @[
        [@"/var/jb/usr/bin" stringByAppendingPathComponent:command],
        [@"/var/jb/usr/sbin" stringByAppendingPathComponent:command],
        [@"/usr/bin" stringByAppendingPathComponent:command],
        [@"/usr/sbin" stringByAppendingPathComponent:command],
        [@"/bin" stringByAppendingPathComponent:command],
        [@"/sbin" stringByAppendingPathComponent:command]
    ];
}

+ (void)runCommand:(NSString *)command
         arguments:(NSArray<NSString *> *)arguments
        completion:(IFCommandCompletion)completion {
    NSString *path = [IFetchCore executablePathForCandidates:[self pathsForCommand:command]];
    if (path.length == 0) {
        completion(-1, 0, IFActionError(ENOENT,
            [NSString stringWithFormat:@"Command %@ was not found", command]));
        return;
    }

    NSMutableArray<NSString *> *allArguments = [NSMutableArray arrayWithObject:command];
    [allArguments addObjectsFromArray:arguments ?: @[]];
    char **argv = calloc(allArguments.count + 1, sizeof(char *));
    if (argv == NULL) {
        completion(-1, 0, IFActionError(ENOMEM, @"Unable to allocate command arguments"));
        return;
    }
    for (NSUInteger index = 0; index < allArguments.count; index++) {
        argv[index] = (char *)allArguments[index].UTF8String;
    }

    pid_t pid = 0;
    int spawnResult = posix_spawn(&pid, path.fileSystemRepresentation, NULL, NULL, argv, environ);
    free(argv);
    if (spawnResult != 0) {
        completion(-1, 0, IFActionError(spawnResult,
            [NSString stringWithUTF8String:strerror(spawnResult)] ?: @"Unable to start command"));
        return;
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        int status = 0;
        pid_t waited = waitpid(pid, &status, 0);
        int exitCode = waited >= 0 && WIFEXITED(status) ? WEXITSTATUS(status) : -1;
        int signalNumber = waited >= 0 && WIFSIGNALED(status) ? WTERMSIG(status) : 0;
        NSError *error = waited < 0
            ? IFActionError(errno, [NSString stringWithUTF8String:strerror(errno)] ?: @"waitpid failed")
            : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(exitCode, signalNumber, error);
        });
    });
}

+ (BOOL)terminateProcess:(pid_t)pid error:(NSError **)error {
    if (pid <= 1 || pid == getpid()) {
        if (error != NULL) {
            *error = IFActionError(EPERM, @"Protected process");
        }
        return NO;
    }
    if (kill(pid, SIGTERM) == 0) {
        return YES;
    }
    if (error != NULL) {
        *error = IFActionError(errno,
            [NSString stringWithUTF8String:strerror(errno)] ?: @"kill failed");
    }
    return NO;
}

@end
