/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2018 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiDimension.h"
#import "TiUIView.h"
#import <WebKit/WebKit.h>

@interface TiWkwebviewWebView : TiUIView <WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler> {
  WKWebView *_webView;
  NSString *_pageToken;

  TiDimension width;
  TiDimension height;
  CGFloat autoHeight;
  CGFloat autoWidth;

  BOOL _willHandleTouches;
  NSArray<NSString *> *_blacklistedURLs;
  NSURL *_currentURL;
  UIActivityIndicatorView *_loadingIndicator;
}

// Used from the proxy
- (void)setHtml_:(id)args;

- (void)registerNotificationCenter;

- (WKWebView *)webView;

- (void)viewDidClose;

- (void)fireEvent:(id)listener withObject:(id)obj remove:(BOOL)yn thisObject:(id)thisObject_;

@end
