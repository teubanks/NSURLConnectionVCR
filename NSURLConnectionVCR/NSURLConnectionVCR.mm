//
//  NSURLConnectionVCR.m
//
//  Created by Martijn Thé on 19-02-12.
//  Copyright (c) 2012 martijnthe.nl All rights reserved.
//

#import "NSURLConnectionVCR.h"
#import "SKUtils.h"
#import <CommonCrypto/CommonDigest.h>
#import <objc/runtime.h>
 
NSString* NSURLConnectionVCRErrorDomain = @"NSURLConnectionVCRErrorDomain";
struct objc_class;
__strong static NSString* casettesPath;


@interface VCRCache : NSObject <NSCoding>
@property (nonatomic, readwrite, strong) NSURLResponse* response;
@property (nonatomic, readwrite, strong) NSData* responseBody;
+ (VCRCache*)loadCacheForRequest:(NSURLRequest*)request;
+ (BOOL)storeResponse:(NSURLResponse*)response withResponseBody:(NSData*)data forRequest:(NSURLRequest*)request;
@end


@interface NSURLConnectionVCR ()
@property (nonatomic, retain, readwrite) NSURLConnection* origConnection;
@end


@implementation NSURLConnectionVCR {
    NSURLConnection* origConnection;
}
@synthesize origConnection;

static IMP allocImplementationOrig = NULL;
static id VCRAllocImplementation(id theSelf, SEL cmd, ...) {
    NSURLConnectionVCR* vcr = [NSURLConnectionVCR alloc];
    // Call original +alloc method:
    NSURLConnection* origConn = allocImplementationOrig(theSelf, cmd);
    [vcr setOrigConnection:origConn];
    return vcr;
}

+ (BOOL)startVCRWithPath:(NSString*)path error:(NSError *__autoreleasing *)error {
    if ([self isVCRStarted]) {
        if (error) {
            *error = [NSError errorWithDomain:NSURLConnectionVCRErrorDomain code:NSURLConnectionVCRErrorAlreadyStarted userInfo:nil];
        }
        return NO;
    } else {
        Class connectionClass = NSClassFromString(@"NSURLConnection");
        Class connectionMetaClass = objc_getMetaClass("NSURLConnection");
        Method origMethod = class_getClassMethod(connectionClass, @selector(alloc));
        allocImplementationOrig = method_getImplementation(origMethod);
        class_replaceMethod(connectionMetaClass, @selector(alloc), VCRAllocImplementation, "@@:");        
        
        casettesPath = path;
        
        return YES;
    }
}

+ (BOOL)stopVCRWithError:(NSError**)error {
    if ([self isVCRStarted] == NO) {
        if (error) {
            *error = [NSError errorWithDomain:NSURLConnectionVCRErrorDomain code:NSURLConnectionVCRErrorAlreadyStopped userInfo:nil];
        }
        return NO;
    } else {
        Class connectionMetaClass = objc_getMetaClass("NSURLConnection");
        class_replaceMethod(connectionMetaClass, @selector(alloc), allocImplementationOrig, "@@:");        
        allocImplementationOrig = NULL;
        
        casettesPath = nil;
        
        return YES;
    }
}

+ (BOOL)isVCRStarted {
    return (allocImplementationOrig != NULL);
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    return [origConnection respondsToSelector:aSelector];
}

- (void)doesNotRecognizeSelector:(SEL)aSelector {
    
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    return origConnection;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    
}

@end


@interface VCRCache (Private)
+ (NSString*)hashForRequest:(NSURLRequest*)request;
+ (NSString*)filePathForRequest:(NSURLRequest*)request;
@end


@implementation VCRCache
@synthesize response;
@synthesize responseBody;

+ (VCRCache*)loadCacheForRequest:(NSURLRequest*)request {
    VCRCache* cache = [NSKeyedUnarchiver unarchiveObjectWithFile:[self filePathForRequest:request]];
    return cache;
}

+ (BOOL)storeResponse:(NSURLResponse*)response withResponseBody:(NSData*)data forRequest:(NSURLRequest*)request {
    VCRCache* cache = [[VCRCache alloc] init];
    cache.response = response;
    cache.responseBody = data;
    return [NSKeyedArchiver archiveRootObject:cache toFile:[self filePathForRequest:request]];
}

- (id)initWithCoder:(NSCoder *)coder {
    if (self) {
        self.response = [coder decodeObjectForKey:@"response"];
        self.responseBody = [coder decodeObjectForKey:@"responseBody"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:response forKey:@"response"];
    [aCoder encodeObject:responseBody forKey:@"responseBody"];
}

@end


@implementation VCRCache (Private)

+ (NSString*)hashForRequest:(NSURLRequest*)request {
    NSData* data = [NSKeyedArchiver archivedDataWithRootObject:request];
    unsigned char md5[CC_MD5_DIGEST_LENGTH];
    CC_MD5([data bytes], (CC_LONG)[data length], md5);
    NSString* md5String = (__bridge_transfer NSString*)SKUtilsCreateStringHexadecimalRepresentationOfBytes(md5, CC_MD5_DIGEST_LENGTH);
    return md5String;
}

+ (NSString*)filePathForRequest:(NSURLRequest*)request {
    NSString* filePath = [casettesPath stringByAppendingPathComponent:[self hashForRequest:request]];
    return filePath;
}

@end
