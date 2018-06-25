/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2016 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiViewProxy.h"
#import "TiEvaluator.h"

@interface TiWkwebviewWebViewProxy : TiViewProxy <TiEvaluator> {
    NSMutableArray<NSString *> *genericProperties;
    NSArray *_allowedURLSchemes;
    NSString *_pageToken;
}

- (void)setPageToken:(NSString *)pageToken;

@end
