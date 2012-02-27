//
//  NSURLConnectionVCRTests.m
//  NSURLConnectionVCRTests
//
//  Created by Martijn Thé on 2/25/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NSURLConnectionVCRTests.h"
#import "NSURLConnectionVCR.h"
#import "HTTPServer.h"
#import "HTTPConnection.h"

// The SRCROOT preprocessor variable is set using the "Preprocessor Macros Not Used in Precompiled Headers" (GCC_PREPROCESSOR_DEFINITIONS_NOT_USED_IN_PRECOMPS) build setting.
// This way the caches can be committed together with the tests as part of your project's source, which is makes the tests independent on internet connectivity, if run once and committed.

#define QUOTE(str) #str
#define EXPAND_AND_QUOTE(str) QUOTE(str)

@interface BreakableHTTPConnection : HTTPConnection
+ (void)setBroken:(BOOL)broken;
@end

@interface NSURLResponse (Testing)
- (BOOL)isEqualIgnoringVolatileHTTPHeaders:(NSURLResponse*)otherResponse;
@end

@interface ConnectionDelegate : NSObject <NSURLConnectionDelegate>
@property (nonatomic, readonly) NSURLResponse* response;
@property (nonatomic, readonly) NSData* responseData;
@property (nonatomic, readonly) NSError* error;
@property (nonatomic, readonly) BOOL isDone;
@end

@implementation NSURLConnectionVCRTests {
    NSString* tapesPath;
    NSString* docRoot;
    NSString* testFilename;
    NSURL* testURL;
    HTTPServer* httpServer;
    NSOperationQueue* bgQueue;
}

- (void)setUp {
    [super setUp];
    
    NSString* srcroot = [NSString stringWithFormat:@"%s", EXPAND_AND_QUOTE(SRCROOT)];
    tapesPath = [srcroot stringByAppendingPathComponent:@"NSURLConnectionVCRTests/VCRTapes"];
    
    // These tests will run against a local server, so they run fast and are not dependent on an external server:
    httpServer = [[HTTPServer alloc] init];
    [httpServer setConnectionClass:[BreakableHTTPConnection class]];
    UInt16 port = 2048;
    [httpServer setPort:port];
    docRoot = [srcroot stringByAppendingPathComponent:@"NSURLConnectionVCRTests/htdocs"];
    [httpServer setDocumentRoot:docRoot];
    
    NSError *error = nil;
    
    int retries = 0;
    while ([httpServer start:&error] == NO) {
        [NSThread sleepForTimeInterval:0.1];
        ++retries;
        if (retries > 20) {
            STFail(@"Error starting HTTP Server: %@", error);
            break;
        }
    }
    
    // testURL = [NSURL URLWithString:@"https://raw.github.com/gist/1909468/267a404619b83a3d897b10d9904fd9644f5486d2/NSURLConnectionVCRTest.json"];
    testFilename = @"TestResponse.json";
    testURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%u/%@", port, testFilename]];
    
    bgQueue = [[NSOperationQueue alloc] init];
    [bgQueue setMaxConcurrentOperationCount:1];
    
    [BreakableHTTPConnection setBroken:NO];
    [NSURLConnectionVCR startVCRWithPath:tapesPath error:nil];
}

- (void)tearDown {
    [super tearDown];
    [NSURLConnectionVCR stopVCRWithError:nil];
    [httpServer stop];
}

- (void)testBrokenServer {
    [NSURLConnectionVCR stopVCRWithError:nil];
    NSURLRequest* request = [NSURLRequest requestWithURL:testURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30.0];
    NSHTTPURLResponse* response = nil;
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:nil];
    STAssertTrue([response statusCode] == 200, @"Expecting 200 status");
    
    [BreakableHTTPConnection setBroken:YES];
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:nil];
    STAssertTrue([response statusCode] == 400, @"Expecting 400 status after breaking the server");
}

- (void)testStarted {
    STAssertTrue([NSURLConnectionVCR isVCRStarted], @"VCR expected to be started");
    id connection = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:testURL] delegate:self];
    STAssertTrue([connection class] == [NSURLConnectionVCR class], @"[NSURLConnection alloc] is expected to create a NSURLConnectionVCR object.");
}

- (void)testAlreadyStarted {
    NSError* error = nil;
    [NSURLConnectionVCR startVCRWithPath:tapesPath error:&error];
    STAssertTrue(error && [error code] == NSURLConnectionVCRErrorAlreadyStarted, @"Expecting error, because already started.");
}

- (void)testAlreadyStopped {
    NSError* error = nil;
    BOOL success;
    success = [NSURLConnectionVCR stopVCRWithError:&error];
    STAssertTrue(success && error == nil, @"Expecting no errors, because should be able to stop when VCR is started.");
    success = [NSURLConnectionVCR stopVCRWithError:&error];
    STAssertTrue(success == NO && error && [error code] == NSURLConnectionVCRErrorAlreadyStopped, @"Expecting error, because already stopped.");
}

- (void)testSetNonExistingPath {
    NSError* error = nil;
    NSString* randomPath;
    BOOL fileExists;
    NSFileManager* fm = [NSFileManager defaultManager];
    do {
        randomPath = [NSTemporaryDirectory() stringByAppendingPathExtension:[NSString stringWithFormat:@"%i", arc4random()]];
        fileExists = [fm fileExistsAtPath:randomPath];
    } while (fileExists == YES);
    BOOL success = [NSURLConnectionVCR setPath:randomPath error:&error];
    STAssertTrue(success && error == nil, @"Expecting no errors when setting a non-existing path");
}

- (void)testSetNilPath {
    NSError* error = nil;
    BOOL success = [NSURLConnectionVCR setPath:nil error:&error];
    STAssertTrue(success && error == nil, @"Expecting no error when setting nil path");
}

- (void)testSetNonExistingInvalidPath {
    NSError* error = nil;
    BOOL success = [NSURLConnectionVCR setPath:@"/:invalid:path" error:&error];
    STAssertTrue(success == NO && error && [error code] == NSURLConnectionVCRErrorCouldNotCreateDirectory, @"Expecting error when setting an invalid path");
}

- (void)testStartWithInvalidPath {
    [NSURLConnectionVCR stopVCRWithError:nil];
    NSError* error = nil;
    BOOL success = [NSURLConnectionVCR startVCRWithPath:@"/:invalid:path" error:&error];
    STAssertTrue(success == NO && error && [error code] == NSURLConnectionVCRErrorCouldNotCreateDirectory, @"Expecting error when setting an invalid path");    
}

- (void)testSetPathNotADirectory {
    NSError* error = nil;
    NSBundle* testBundle = [NSBundle bundleForClass:[self class]];
    NSString* filePath = [testBundle executablePath];
    BOOL success = [NSURLConnectionVCR setPath:filePath error:&error];
    STAssertTrue(success == NO && error && [error code] == NSURLConnectionVCRErrorPathIsNotADirectory, @"Expecting error when setting a path that refers to a file");
}

- (void)testSynchronousRequest {
    NSError* error = nil;
    NSURLRequest* request = [NSURLRequest requestWithURL:testURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30.0];
    
    // Do request with no VCR:
    [NSURLConnectionVCR stopVCRWithError:nil];
    NSURLResponse* responseNoVCR = nil;
    NSData* dataNoVCR = [NSURLConnection sendSynchronousRequest:request returningResponse:&responseNoVCR error:&error];
    if (dataNoVCR == nil || error) {
        STFail(@"Problem fetching testURL (%@): %@", testURL, error);
    }
    
    // Do request with cold VCR:
    [NSURLConnectionVCR startVCRWithPath:tapesPath error:&error];
    if ([NSURLConnectionVCR hasCacheForRequest:request]) {
        [NSURLConnectionVCR deleteCacheForRequest:request error:nil];
    }
    NSURLResponse* responseColdVCR = nil;
    NSData* dataColdVCR = [NSURLConnection sendSynchronousRequest:request returningResponse:&responseColdVCR error:&error];
    if (dataColdVCR == nil || error) {
        STFail(@"Problem fetching testURL with cold VCR (%@): %@", testURL, error);
    }
    STAssertTrue([dataColdVCR isEqual:dataNoVCR], @"Response body without VCR is expected to be equal to response body with cold VCR.");
    STAssertTrue([responseColdVCR isEqualIgnoringVolatileHTTPHeaders:responseNoVCR], @"Response without VCR is expected to be equal to response with cold VCR.");

    // Do request with hot VCR:
    [BreakableHTTPConnection setBroken:YES];
    STAssertTrue([NSURLConnectionVCR hasCacheForRequest:request], @"VCR is expected to have a cache for the request by now.");
    NSURLResponse* responseHotVCR = nil;
    NSData* dataHotVCR = [NSURLConnection sendSynchronousRequest:request returningResponse:&responseHotVCR error:&error];
    if (dataHotVCR == nil || error) {
        STFail(@"Problem fetching testURL with hot VCR (%@): %@", testURL, error);
    }
    STAssertTrue([dataHotVCR isEqual:dataNoVCR], @"Response body without VCR is expected to be equal to response body with cold VCR.");
    STAssertTrue([responseHotVCR isEqualIgnoringVolatileHTTPHeaders:responseNoVCR], @"Response without VCR is expected to be equal to response with cold VCR.");
}

- (void)testAsynchronousRequestWithQueues {
    __block NSError* error = nil;
    __block BOOL done = NO;
    NSURLRequest* request = [NSURLRequest requestWithURL:testURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30.0];
    
    // Do request with no VCR:
    [NSURLConnectionVCR stopVCRWithError:nil];
    __block NSURLResponse* responseNoVCR = nil;
    __block NSData* dataNoVCR = nil;
    [NSURLConnection sendAsynchronousRequest:request queue:bgQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *theError) {
        responseNoVCR = response;
        dataNoVCR = data;
        error = theError;
        done = YES;
    }];
    while (done == NO) {
        [NSThread sleepForTimeInterval:0.1];
    }
    if (dataNoVCR == nil || error) {
        STFail(@"Problem fetching testURL (%@): %@", testURL, error);
    }
    
    // Do request with cold VCR:
    [NSURLConnectionVCR startVCRWithPath:tapesPath error:&error];
    if ([NSURLConnectionVCR hasCacheForRequest:request]) {
        [NSURLConnectionVCR deleteCacheForRequest:request error:nil];
    }
    __block NSURLResponse* responseColdVCR = nil;
    __block NSData* dataColdVCR = nil;
    done = NO;
    [NSURLConnection sendAsynchronousRequest:request queue:bgQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *theError) {
        responseColdVCR = response;
        dataColdVCR = data;
        error = theError;
        done = YES;
    }];
    while (done == NO) {
        [NSThread sleepForTimeInterval:0.1];
    }
    if (dataColdVCR == nil || error) {
        STFail(@"Problem fetching testURL with cold VCR (%@): %@", testURL, error);
    }
    STAssertTrue([dataColdVCR isEqual:dataNoVCR], @"Response body without VCR is expected to be equal to response body with cold VCR.");
    STAssertTrue([responseColdVCR isEqualIgnoringVolatileHTTPHeaders:responseNoVCR], @"Response without VCR is expected to be equal to response with cold VCR.");
    
    // Do request with hot VCR:
    [BreakableHTTPConnection setBroken:YES];
    STAssertTrue([NSURLConnectionVCR hasCacheForRequest:request], @"VCR is expected to have a cache for the request by now.");
    __block NSURLResponse* responseHotVCR = nil;
    __block NSData* dataHotVCR = nil;
    done = NO;
    [NSURLConnection sendAsynchronousRequest:request queue:bgQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *theError) {
        responseHotVCR = response;
        dataHotVCR = data;
        error = theError;
        done = YES;
    }];
    while (done == NO) {
        [NSThread sleepForTimeInterval:0.1];
    }
    if (dataHotVCR == nil || error) {
        STFail(@"Problem fetching testURL with hot VCR (%@): %@", testURL, error);
    }
    STAssertTrue([dataHotVCR isEqual:dataNoVCR], @"Response body without VCR is expected to be equal to response body with cold VCR.");
    STAssertTrue([responseHotVCR isEqualIgnoringVolatileHTTPHeaders:responseNoVCR], @"Response without VCR is expected to be equal to response with cold VCR.");
}

- (void)testAsynchronousRequestWithDelegates {    
    NSURLConnection* connection;
    NSURLRequest* request = [NSURLRequest requestWithURL:testURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30.0];
    
    // Do request with no VCR:
    [NSURLConnectionVCR stopVCRWithError:nil];
    ConnectionDelegate *noVCRDelegate = [[ConnectionDelegate alloc] init];
    connection = [[NSURLConnection alloc] initWithRequest:request delegate:noVCRDelegate startImmediately:YES];
    while ([noVCRDelegate isDone] == NO) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    if (noVCRDelegate.responseData == nil || noVCRDelegate.error) {
        STFail(@"Problem fetching testURL (%@): %@", testURL, noVCRDelegate.error);
    }
    
    // Do request with cold VCR:
    [NSURLConnectionVCR startVCRWithPath:tapesPath error:nil];
    if ([NSURLConnectionVCR hasCacheForRequest:request]) {
        [NSURLConnectionVCR deleteCacheForRequest:request error:nil];
    }
    ConnectionDelegate *coldVCRDelegate = [[ConnectionDelegate alloc] init];
    connection = [[NSURLConnection alloc] initWithRequest:request delegate:coldVCRDelegate startImmediately:YES];
    while ([coldVCRDelegate isDone] == NO) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    if (coldVCRDelegate.responseData == nil || coldVCRDelegate.error) {
        STFail(@"Problem fetching testURL with cold VCR (%@): %@", testURL, coldVCRDelegate.error);
    }
    STAssertTrue([coldVCRDelegate.responseData isEqual:noVCRDelegate.responseData], @"Response body without VCR is expected to be equal to response body with cold VCR.");
    STAssertTrue([coldVCRDelegate.response isEqualIgnoringVolatileHTTPHeaders:noVCRDelegate.response], @"Response without VCR is expected to be equal to response with cold VCR.");
    
    // Do request with hot VCR:
    [BreakableHTTPConnection setBroken:YES];
    ConnectionDelegate *hotVCRDelegate = [[ConnectionDelegate alloc] init];
    connection = [[NSURLConnection alloc] initWithRequest:request delegate:hotVCRDelegate startImmediately:YES];
    while ([hotVCRDelegate isDone] == NO) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    if (hotVCRDelegate.responseData == nil || hotVCRDelegate.error) {
        STFail(@"Problem fetching testURL with hot VCR (%@): %@", testURL, hotVCRDelegate.error);
    }
    STAssertTrue([hotVCRDelegate.responseData isEqual:noVCRDelegate.responseData], @"Response body without VCR is expected to be equal to response body with cold VCR.");
    STAssertTrue([hotVCRDelegate.response isEqualIgnoringVolatileHTTPHeaders:noVCRDelegate.response], @"Response without VCR is expected to be equal to response with cold VCR.");
}

//- (void)testZzzSleepSoInstrumentsCanFindLeaks {
//    [NSThread sleepForTimeInterval:11.];
//}

@end

@implementation NSURLResponse (Testing)

- (BOOL)isEqualIgnoringVolatileHTTPHeaders:(NSURLResponse*)otherResponse {
    if ([self isKindOfClass:[NSHTTPURLResponse class]] && [otherResponse isKindOfClass:[NSHTTPURLResponse class]]) {
        NSMutableDictionary* headersSelf = [NSMutableDictionary dictionaryWithDictionary:[(NSHTTPURLResponse*)self allHeaderFields]];
        NSMutableDictionary* headersOther = [NSMutableDictionary dictionaryWithDictionary:[(NSHTTPURLResponse*)otherResponse allHeaderFields]];
        NSArray* ignoreKeys = [NSArray arrayWithObjects:@"Date", @"Expires", @"X-Runtime", nil];
        for (NSString* key in ignoreKeys) {
            [headersSelf removeObjectForKey:key];
            [headersOther removeObjectForKey:key];
        }
        // Hmm.. it seems -[NSURLResponse isEqual:] is just doing a pointer comparison...? Let's roll our own then:
        return [self.URL isEqual:otherResponse.URL] && [headersOther isEqualToDictionary:headersSelf] && [(NSHTTPURLResponse*)self statusCode] == [(NSHTTPURLResponse*)otherResponse statusCode];
    } else {
        return [self isEqual:otherResponse];
    }
}

@end


@interface HTTPConnection (Private)
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData*)data withTag:(long)tag; // to avoid compiler warnings/errors
@end


@implementation BreakableHTTPConnection

static BOOL isBroken = NO;
+ (void)setBroken:(BOOL)broken {
    @synchronized(self) {
        isBroken = broken;
    }
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData*)data withTag:(long)tag {
    if (isBroken) {
        [self handleInvalidRequest:nil];
    } else {
        [super socket:sock didReadData:data withTag:tag];
    }
}

@end


@implementation ConnectionDelegate {
    NSURLResponse* response;
    NSMutableData* responseData;
    NSError* error;
    BOOL isDone;
}
@synthesize response;
@synthesize responseData;
@synthesize error;
@synthesize isDone;

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)theError {
    error = theError;
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response {
    return request;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)theResponse {
    response = theResponse;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if (responseData == nil) {
        long long expectedContentLength = [response expectedContentLength];
        responseData = [NSMutableData dataWithLength:expectedContentLength];
    }
    [responseData appendData:data];  
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    return nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    isDone = YES;
}

@end