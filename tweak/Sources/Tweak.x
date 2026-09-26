#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Utils.h"
#import "Logger.h"
#import "Theme.h"
#import "Fonts.h"
#import "LoaderConfig.h"

static NSURL *source;
static BOOL isJailbroken;
static NSString *revengePatchesBundlePath;
static NSURL *pyoncordDirectory;
static LoaderConfig *loaderConfig;

%hook RCTCxxBridge

- (void)executeApplicationScript:(NSData *)script url:(NSURL *)url async:(BOOL)async {
    if (![url.absoluteString containsString:@"main.jsbundle"]) {
        return %orig;
    }

    // Inline payload - loads Revenge bundle from GitHub at runtime
    NSString *payloadJS = @"globalThis.__PYON_LOADER__ = { loaderName: \"WebCord\", loaderVersion: PACKAGE_VERSION, hasThemeSupport: true, storedTheme: null, fontPatch: 2 };"
        "(async () => { try { const res = await fetch(\"https://github.com/revenge-mod/revenge-bundle/releases/latest/download/revenge.min.js\"); "
        "if (!res.ok) throw new Error(\"HTTP \" + res.status); const js = await res.text(); (0, eval)(js); } "
        "catch (e) { console.error(\"[WebCord] Failed to load bundle:\", e); } })();";
    NSData *patchData = [payloadJS dataUsingEncoding:NSUTF8StringEncoding];
    RevengeLog(@"Injecting loader");
    %orig(patchData, source, YES);

    __block NSData *bundle = [NSData dataWithContentsOfURL:[pyoncordDirectory URLByAppendingPathComponent:@"bundle.js"]];

    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);

    NSURL *bundleUrl;
    if (loaderConfig.customLoadUrlEnabled && loaderConfig.customLoadUrl) {
        bundleUrl = loaderConfig.customLoadUrl;
        RevengeLog(@"Using custom load URL: %@", bundleUrl.absoluteString);
    } else {
        bundleUrl = [NSURL URLWithString:@"https://github.com/revenge-mod/revenge-bundle/releases/latest/download/revenge.min.js"];
        RevengeLog(@"Using default bundle URL: %@", bundleUrl.absoluteString);
    }

    NSMutableURLRequest *bundleRequest = [NSMutableURLRequest requestWithURL:bundleUrl
                                                               cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                                           timeoutInterval:3.0];

    NSString *bundleEtag = [NSString stringWithContentsOfURL:[pyoncordDirectory URLByAppendingPathComponent:@"etag.txt"]
                                                   encoding:NSUTF8StringEncoding
                                                      error:nil];
    if (bundleEtag && bundle) {
        [bundleRequest setValue:bundleEtag forHTTPHeaderField:@"If-None-Match"];
    }

    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    [[session dataTaskWithRequest:bundleRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode == 200) {
                bundle = data;
                [bundle writeToURL:[pyoncordDirectory URLByAppendingPathComponent:@"bundle.js"] atomically:YES];

                NSString *etag = [httpResponse.allHeaderFields objectForKey:@"Etag"];
                if (etag) {
                    [etag writeToURL:[pyoncordDirectory URLByAppendingPathComponent:@"etag.txt"]
                         atomically:YES
                           encoding:NSUTF8StringEncoding
                              error:nil];
                }
            }
        }
        dispatch_group_leave(group);
    }] resume];

    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

    NSString *themeString = [NSString stringWithContentsOfURL:[pyoncordDirectory URLByAppendingPathComponent:@"current-theme.json"]
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil];
    if (themeString) {
        NSString *jsCode = [NSString stringWithFormat:@"globalThis.__PYON_LOADER__.storedTheme=%@", themeString];
        %orig([jsCode dataUsingEncoding:NSUTF8StringEncoding], source, async);
    }

    NSData *fontData = [NSData dataWithContentsOfURL:[pyoncordDirectory URLByAppendingPathComponent:@"fonts.json"]];
    if (fontData) {
        NSError *jsonError;
        NSDictionary *fontDict = [NSJSONSerialization JSONObjectWithData:fontData options:0 error:&jsonError];
        if (!jsonError && fontDict[@"main"]) {
            RevengeLog(@"Found font configuration, applying...");
            patchFonts(fontDict[@"main"], fontDict[@"name"]);
        }
    }

    if (bundle) {
        RevengeLog(@"Executing JS bundle");
        %orig(bundle, source, async);
    }

    NSURL *preloadsDirectory = [pyoncordDirectory URLByAppendingPathComponent:@"preloads"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:preloadsDirectory.path]) {
        NSError *error = nil;
        NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:preloadsDirectory
                                                        includingPropertiesForKeys:nil
                                                                           options:0
                                                                             error:&error];
        if (!error) {
            for (NSURL *fileURL in contents) {
                if ([[fileURL pathExtension] isEqualToString:@"js"]) {
                    RevengeLog(@"Executing preload JS file %@", fileURL.absoluteString);
                    NSData *data = [NSData dataWithContentsOfURL:fileURL];
                    if (data) {
                        %orig(data, source, async);
                    }
                }
            }
        } else {
            RevengeLog(@"Error reading contents of preloads directory");
        }
    }

    %orig(script, url, async);
}

%end

%ctor {
    @autoreleasepool {
        source = [NSURL URLWithString:@"revenge"];

        NSString *install_prefix = @"/var/jb";
        isJailbroken = [[NSFileManager defaultManager] fileExistsAtPath:install_prefix];

        NSString *bundlePath = [NSString stringWithFormat:@"%@/Library/Application Support/WebCordResources.bundle", install_prefix];
        RevengeLog(@"Is jailbroken: %d", isJailbroken);
        RevengeLog(@"Bundle path for jailbroken: %@", bundlePath);

        NSString *jailedPath = [[NSBundle mainBundle].bundleURL.path stringByAppendingPathComponent:@"WebCordResources.bundle"];
        RevengeLog(@"Bundle path for jailed: %@", jailedPath);

        revengePatchesBundlePath = isJailbroken ? bundlePath : jailedPath;
        RevengeLog(@"Selected bundle path: %@", revengePatchesBundlePath);

        BOOL bundleExists = [[NSFileManager defaultManager] fileExistsAtPath:revengePatchesBundlePath];
        RevengeLog(@"Bundle exists at path: %d", bundleExists);

        NSError *error = nil;
        NSArray *bundleContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:revengePatchesBundlePath error:&error];
        if (error) {
            RevengeLog(@"Error listing bundle contents: %@", error);
        } else {
            RevengeLog(@"Bundle contents: %@", bundleContents);
        }

pyoncordDirectory = getPyoncordDirectory();
        loaderConfig = [[LoaderConfig alloc] init];
        [loaderConfig loadConfig];
        
        %init;
    }
}
