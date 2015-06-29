//
//  CopyLatLngOnMaps.m
//  CopyLatLngOnMaps
//

@import ObjectiveC;
#import "CopyLatLngOnMaps.h"

@implementation NSObject (CopyLatLngOnMaps)

- (NSArray *)CopyLatLngOnMaps_sharingServicePicker:(NSSharingServicePicker *)sharingServicePicker sharingServicesForItems:(NSArray *)items proposedSharingServices:(NSArray *)proposedServices
{
    NSArray *services = [self CopyLatLngOnMaps_sharingServicePicker:sharingServicePicker sharingServicesForItems:items proposedSharingServices:proposedServices];
    
    NSURL *url = nil;
    for (id item in items) {
        if ([item isKindOfClass:[NSURL class]]) {
            url = item;
            break;
        }
    }
    
    // See Apple URL Scheme Reference
    // https://developer.apple.com/library/mac/featuredarticles/iPhoneURLScheme_Reference/MapLinks/MapLinks.html
    NSString *query = [url query];
    if ([[url host] isEqualToString:@"maps.apple.com"] && query) {
        
        // Prepare Regex
        static NSRegularExpression *regex = nil;
        if (!regex) {
            NSError *error = nil;
            regex = [NSRegularExpression regularExpressionWithPattern:@"(q|h?near|sll)=(-?\\d+\\.\\d+,-?\\d+\\.\\d+)" options:0 error:&error];
            if (error) {
                NSLog(@"NSRegularExpression regularExpressionWithPattern:options:error:%@", error);
            }
        }

		NSLog(@"processing query: %@", query);
        
        // Search latitude,longitude from query
        __block NSString *latlng = nil;
        __block NSString *candidate = nil;
        [regex enumerateMatchesInString:query options:0 range:NSMakeRange(0, [query length]) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop){
            NSRange matchRange = result.range;
            if (matchRange.location != NSNotFound) {
                NSString *paramName = [query substringWithRange:[result rangeAtIndex:1]];
                if ([paramName isEqualToString:@"q"]) {
                    // Use parameter "q" as latlng if it's formated in "lat,lng".
                    latlng = [query substringWithRange:[result rangeAtIndex:2]];
                    *stop = YES;
					NSLog(@"found latlng %@", latlng);
                } else if ([paramName hasSuffix:@"near"]) {
                    // Use near as candidate if it's formated in "lat,lng".
                    candidate = [query substringWithRange:[result rangeAtIndex:2]];
					NSLog(@"found another latlng candidate %@", latlng);
				} else if ([paramName isEqualToString:@"sll"]) {
					candidate = [query substringWithRange:[result rangeAtIndex:2]];
					NSLog(@"found another latlng candidate for point of interest %@", latlng);
				} else {
					NSLog(@"skipping param (not latlng candidate) %@", paramName);
				}
            }
        }];
		NSLog(@"latlng was %@, candidate is %@", latlng, candidate);
        latlng =  latlng ?: candidate;

        // Add custom service if found latitude,longitude
        if (latlng) {
            NSString *title = [NSString stringWithFormat:@"Copy \"%@\" to Pasteboard", latlng];
            NSSharingService *customService = [[NSSharingService alloc] initWithTitle:title image:nil alternateImage:nil handler:^{
                NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
                [pasteboard clearContents];
                [pasteboard writeObjects:@[latlng]];
            }];
			NSLog(@"new service for latlng %@ is %@", latlng, customService);
            services = [services arrayByAddingObject:@[customService]];
		} else {
			NSLog(@"no latlng or candidate, so no sharing service");
		}
	} else {
		NSLog(@"no latlang because of either: %@ != maps.apple.com OR '%@' is empty", url.host, query);
	}

    return services;
}

@end

@implementation CopyLatLngOnMaps

/*!
 * A special method called by SIMBL once the application has started and all classes are initialized.
 */
+ (void) load
{
    id plugin = [self sharedInstance];
    // ... do whatever
    if (plugin) {
        Class from = objc_getClass("NVSharingController");
        Class to = objc_getClass("NSObject");
        method_exchangeImplementations(class_getInstanceMethod(from, @selector(sharingServicePicker:sharingServicesForItems:proposedSharingServices:)),
                                       class_getInstanceMethod(to, @selector(CopyLatLngOnMaps_sharingServicePicker:sharingServicesForItems:proposedSharingServices:)));
    }
}


/*!
 * @return the single static instance of the plugin object
 */
+ (instancetype) sharedInstance;
{
    static id plugin = nil;
    
    if (plugin == nil)
        plugin = [[self alloc] init];
    
    return plugin;
}

@end
