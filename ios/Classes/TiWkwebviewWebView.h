/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2016 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiUIView.h"
#import "TiDimension.h"
#import <WebKit/WebKit.h>

@interface TiWkwebviewWebView : TiUIView <WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler> {
    WKWebView *_webView;
    NSString *_pageToken;

    TiDimension width;
    TiDimension height;
    CGFloat autoHeight;
    CGFloat autoWidth;
    
    BOOL willHandleTouches;
    NSURL *_currentURL;
}

- (void)registerNotificationCenter;

- (WKWebView *) webView;

- (void)fireEvent:(id)listener withObject:(id)obj remove:(BOOL)yn thisObject:(id)thisObject_;

@end
