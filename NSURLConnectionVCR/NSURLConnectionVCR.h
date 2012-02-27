//
//  NSURLConnectionVCR.h
//
//  Created by Martijn Thé on 19-02-12.
//  Copyright (c) 2012 martijnthe.nl All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  NSURLConnectionVCR provides a way to re-play NSURLConnection HTTP responses.
 *  It is inspired on Ruby's VCR.
 */

extern NSString* NSURLConnectionVCRErrorDomain;

enum NSURLConnectionVCRErrorCodes {
    NSURLConnectionVCRErrorAlreadyStarted,
    NSURLConnectionVCRErrorAlreadyStopped
};

@interface NSURLConnectionVCR : NSObject
+ (BOOL)startVCRWithPath:(NSString*)path error:(NSError**)error;
+ (BOOL)stopVCRWithError:(NSError**)error;
+ (BOOL)isVCRStarted;
@end
