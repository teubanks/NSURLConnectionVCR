#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#import "VCRGetPreview.h"

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options);
//void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview);


OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options) {
    NSData* responseData = nil;
    NSString* displayName = nil;
    NSString* textEncoding = nil;
    NSString* mimeType = nil;
    NSString* UTType = nil;
    
    OSStatus status = VCRGetPreviewData((__bridge NSURL*)url, &responseData, NULL, &displayName, &mimeType, &UTType, &textEncoding);
    
    if (status == noErr && displayName && textEncoding && responseData && UTType) {
        NSMutableDictionary *props = [[NSMutableDictionary alloc] init];
        [props setObject:displayName forKey:(NSString*)kQLPreviewPropertyDisplayNameKey];
        [props setObject:textEncoding forKey:(NSString *)kQLPreviewPropertyTextEncodingNameKey];
        QLPreviewRequestSetDataRepresentation(preview, (__bridge CFDataRef)responseData, (__bridge CFStringRef)UTType, (__bridge CFDictionaryRef)props);
        return noErr;
    } else {
        return -1;
    }
}

//void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview)
//{
//    // Implement only if supported
//}
