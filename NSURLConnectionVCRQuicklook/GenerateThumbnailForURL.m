#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#import "VCRGetPreview.h"

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize);
//void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail);


OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize) {    
    NSData* responseData = nil;
    NSURLResponse* response = nil;
    NSString* textEncoding = nil;
    NSString* mimeType = nil;
    
    __block OSStatus status = VCRGetPreviewData((__bridge NSURL*)url, &responseData, &response, NULL, &mimeType, NULL, &textEncoding);
    
    if (status == noErr && responseData && response && mimeType && textEncoding) {
		NSRect viewRect = NSMakeRect(0.0, 0.0, 600.0, 800.0);
		float scale = maxSize.height / 800.0;
		NSSize scaleSize = NSMakeSize(scale, scale);
		CGSize thumbSize = NSSizeToCGSize(NSMakeSize((maxSize.width * (600.0/800.0)), maxSize.height));
        
		dispatch_sync(dispatch_get_main_queue(), ^{
            NSURL* originalURL = [response URL];
            WebView* webView = [[WebView alloc] initWithFrame: viewRect];
            [webView scaleUnitSquareToSize: scaleSize];
            [[[webView mainFrame] frameView] setAllowsScrolling:NO];
            [[webView mainFrame] loadData:responseData MIMEType:mimeType textEncodingName:textEncoding baseURL:[originalURL URLByDeletingLastPathComponent]];

            while ([webView isLoading]) {
              CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, true);
            }

            [webView display];

            CGContextRef context = QLThumbnailRequestCreateContext(thumbnail, thumbSize, false, NULL);

            if (context) {
                NSGraphicsContext* nsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:(void*)context flipped:[webView isFlipped]];
                [webView displayRectIgnoringOpacity:[webView bounds] inContext:nsContext];
                QLThumbnailRequestFlushContext(thumbnail, context);
                CFRelease(context);
                status = noErr;
            } else {
                status = -2;
            }
        });
        return status;
	} else {
        return -1;
    }
}

//void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail)
//{
//    // Implement only if supported
//}
