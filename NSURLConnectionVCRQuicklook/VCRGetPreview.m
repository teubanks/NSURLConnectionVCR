//
//  VCRGetPreview.m
//  NSURLConnectionVCR
//
//  Created by Martijn Thé on 2/27/12.
//  Copyright (c) 2012 martijnthe.nl. All rights reserved.
//

#import "VCRGetPreview.h"
#import  "NSURLConnectionVCR.h"

@interface VCRCache : NSObject <NSCoding>
@property (nonatomic, readwrite, strong) NSURLResponse* response;
@property (nonatomic, readwrite, strong) NSData* responseBody;
@end

OSStatus VCRGetPreviewData(NSURL* url,
                           NSData *__autoreleasing *responseData,
                           NSURLResponse *__autoreleasing*response,
                           NSString *__autoreleasing *displayName,
                           NSString *__autoreleasing *mimeType,
                           NSString *__autoreleasing *utType,
                           NSString *__autoreleasing *encoding)
{
    NSData* archiveData = [NSData dataWithContentsOfURL:url];
    if (archiveData) {
        VCRCache* cache = [NSKeyedUnarchiver unarchiveObjectWithData:archiveData];
        
        if (responseData) {
            *responseData = cache.responseBody;
        }
        
        if (response) {
            *response = cache.response;
        }
        
        if (displayName) {
            NSString* _displayName;
            if ([cache.response isKindOfClass:[NSHTTPURLResponse class]]) {
                _displayName = [NSString stringWithFormat:@"%@ [%i]", [[cache.response URL] absoluteString], [(NSHTTPURLResponse*)cache.response statusCode]];
            } else {
                _displayName = [[cache.response URL] absoluteString];
            }
            *displayName = _displayName;
        }
        
        if (encoding) {
            NSString* _encoding = [cache.response textEncodingName];
            if (_encoding == nil) _encoding = @"UTF-8";
            *encoding = _encoding;
        }
        
        NSString* _mimeType = [cache.response MIMEType];
        if (_mimeType == nil) _mimeType = @"text/plain";
        if (mimeType) {
            *mimeType = _mimeType;
        }
        if (utType) {
            CFStringRef supportedTypes[] = {kUTTypeHTML, kUTTypeXML, kUTTypeRTF, kUTTypePlainText, kUTTypeImage, kUTTypePDF, kUTTypeMovie, kUTTypeAudio, NULL};
            for (NSInteger idx = 0; idx < 9; ++idx) {
                *utType = (__bridge NSString*)UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)_mimeType, supportedTypes[idx]);
                if (*utType != nil) {
                    break;
                }
            }
        }
        
        return noErr;
    } else {
        return -1;
    }
}