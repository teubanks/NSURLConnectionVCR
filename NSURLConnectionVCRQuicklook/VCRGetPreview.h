//
//  VCRGetPreview.h
//  NSURLConnectionVCR
//
//  Created by Martijn Thé on 2/27/12.
//  Copyright (c) 2012 martijnthe.nl. All rights reserved.
//

#import <Foundation/Foundation.h>

OSStatus VCRGetPreviewData(NSURL* url,
                           NSData *__autoreleasing *responseData,
                           NSURLResponse *__autoreleasing*response,
                           NSString *__autoreleasing *displayName,
                           NSString *__autoreleasing *mimeType,
                           NSString *__autoreleasing *utType,
                           NSString *__autoreleasing *encoding);