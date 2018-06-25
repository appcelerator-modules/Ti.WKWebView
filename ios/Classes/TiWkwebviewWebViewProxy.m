/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2016 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiWkwebviewWebViewProxy.h"
#import "TiWkwebviewWebView.h"
#import "TiUtils.h"
#import "TiHost.h"

@implementation TiWkwebviewWebViewProxy

- (id)_initWithPageContext:(id<TiEvaluator>)context
{
    if (self = [super _initWithPageContext:context]) {
        [[self webView] registerNotificationCenter];
    }
    
    return self;
}

- (TiWkwebviewWebView *)webView
{
    return (TiWkwebviewWebView *)self.view;
}

- (void)fireEvent:(id)listener withObject:(id)obj remove:(BOOL)yn thisObject:(id)thisObject_
{
  TiThreadPerformOnMainThread(^{
    [[self webView] fireEvent:listener withObject:obj remove:yn thisObject:thisObject_];
  },
                              NO);
}

- (TiHost *)host
{
  return [self _host];
}

- (void)setPageToken:(NSString *)pageToken
{
  if (_pageToken != nil) {
    [[self host] unregisterContext:(id<TiEvaluator>)self forToken:_pageToken];
    _pageToken = nil;
  }
  _pageToken = pageToken;
  [[self host] registerContext:self forToken:_pageToken];
}

- (void)windowDidClose
{
  if (_pageToken != nil) {
    [[self host] unregisterContext:(id<TiEvaluator>)self forToken:_pageToken];
    _pageToken = nil;
  }
  NSNotification *notification = [NSNotification notificationWithName:kTiContextShutdownNotification object:self];
  WARN_IF_BACKGROUND_THREAD_OBJ;
  [[NSNotificationCenter defaultCenter] postNotification:notification];
  [super windowDidClose];
}

- (void)_destroy
{
  if (_pageToken != nil) {
    [[self host] unregisterContext:(id<TiEvaluator>)self forToken:_pageToken];
    _pageToken = nil;
  }
  [super _destroy];
}
#pragma mark - Public APIs

#pragma mark Getters

- (id)disableBounce
{
    return NUMBOOL(![[[[self webView] webView] scrollView] bounces]);
}

- (id)scrollsToTop
{
    return NUMBOOL([[[[self webView] webView] scrollView] scrollsToTop]);
}

- (id)allowsBackForwardNavigationGestures
{
    return NUMBOOL([[[self webView] webView] allowsBackForwardNavigationGestures]);
}

- (id)userAgent
{
    return [[[self webView] webView] customUserAgent] ?: [NSNull null];
}

- (id)url
{
    return [[[[self webView] webView] URL] absoluteString];
}

- (id)title
{
    return [[[self webView] webView] title];
}

- (id)progress
{
    return NUMDOUBLE([[[self webView] webView] estimatedProgress]);
}

- (id)secure
{
    return NUMBOOL([[[self webView] webView] hasOnlySecureContent]);
}

- (id)backForwardList
{
    WKBackForwardList *list = [[[self webView] webView] backForwardList];
    
    NSMutableArray *backList = [NSMutableArray arrayWithCapacity:list.backList.count];
    NSMutableArray *forwardList = [NSMutableArray arrayWithCapacity:list.forwardList.count];
    
    for (WKBackForwardListItem *item in list.backList) {
        [backList addObject:[TiWkwebviewWebViewProxy _dictionaryFromBackForwardItem:item]];
    }
    
    for (WKBackForwardListItem *item in list.forwardList) {
        [forwardList addObject:[TiWkwebviewWebViewProxy _dictionaryFromBackForwardItem:item]];
    }
    
    return @{
        @"currentItem": [TiWkwebviewWebViewProxy _dictionaryFromBackForwardItem:[list currentItem]],
        @"backItem": [TiWkwebviewWebViewProxy _dictionaryFromBackForwardItem:[list backItem]],
        @"forwardItem": [TiWkwebviewWebViewProxy _dictionaryFromBackForwardItem:[list forwardItem]],
        @"backList": backList,
        @"forwardList": forwardList
    };
}

- (id)preferences
{
    return @{
        @"minimumFontSize": NUMFLOAT([[[[[self webView] webView] configuration] preferences] minimumFontSize]),
        @"javaScriptEnabled": NUMBOOL([[[[[self webView] webView] configuration] preferences] javaScriptEnabled]),
        @"javaScriptCanOpenWindowsAutomatically": NUMBOOL([[[[[self webView] webView] configuration] preferences] javaScriptCanOpenWindowsAutomatically]),
    };
}

- (id)selectionGranularity
{
    return NUMINTEGER([[[[self webView] webView] configuration] selectionGranularity]);
}

- (id)mediaTypesRequiringUserActionForPlayback
{
    return NUMUINTEGER([[[[self webView] webView] configuration] mediaTypesRequiringUserActionForPlayback]);
}

- (id)suppressesIncrementalRendering
{
    NUMBOOL([[[[self webView] webView] configuration] suppressesIncrementalRendering]);
}

- (id)allowsInlineMediaPlayback
{
    NUMBOOL([[[[self webView] webView] configuration] allowsInlineMediaPlayback]);
}

- (id)allowsAirPlayMediaPlayback
{
    NUMBOOL([[[[self webView] webView] configuration] allowsAirPlayForMediaPlayback]);
}

- (id)allowsPictureInPictureMediaPlayback
{
    NUMBOOL([[[[self webView] webView] configuration] allowsPictureInPictureMediaPlayback]);
}

- (id)allowedURLSchemes
{
    return _allowedURLSchemes;
}
    
#pragma mark Setter
    
- (void)setAllowedURLSchemes:(NSArray *)schemes
{
    for (id scheme in schemes) {
        ENSURE_TYPE(scheme, NSString);
    }
    
    _allowedURLSchemes = schemes;
}

#pragma mark Methods

- (void)addUserScript:(id)args
{
    ENSURE_SINGLE_ARG(args, NSDictionary);
  
    NSString *source = [TiUtils stringValue:@"source" properties:args];
    WKUserScriptInjectionTime injectionTime = [TiUtils intValue:@"injectionTime" properties:args];
    BOOL mainFrameOnly = [TiUtils boolValue:@"mainFrameOnly" properties:args];
  
    WKUserScript *script = [[WKUserScript alloc] initWithSource:source injectionTime:injectionTime forMainFrameOnly:mainFrameOnly];
    WKUserContentController *controller = [[[[self webView] webView] configuration] userContentController];
    [controller addUserScript:script];
}

- (void)removeAllUserScripts:(id)unused
{
    WKUserContentController *controller = [[[[self webView] webView] configuration] userContentController];
    [controller removeAllUserScripts];
}

- (void)addScriptMessageHandler:(id)value
{
    ENSURE_SINGLE_ARG(value, NSString);
  
    WKUserContentController *controller = [[[[self webView] webView] configuration] userContentController];
    [controller addScriptMessageHandler:[self webView] name:value];
}

- (void)removeScriptMessageHandler:(id)value
{
    ENSURE_SINGLE_ARG(value, NSString);
  
    WKUserContentController *controller = [[[[self webView] webView] configuration] userContentController];
    [controller removeScriptMessageHandlerForName:value];
}

- (NSNumber *)isLoading:(id)unused
{
    return NUMBOOL([[[self webView] webView] isLoading]);
}

- (void)stopLoading:(id)unused
{
    [[[self webView] webView] stopLoading];
}

- (void)reload:(id)unused
{
    [[[self webView] webView] reload];
}

- (void)goBack:(id)unused
{
    [[[self webView] webView] goBack];
}

- (void)goForward:(id)unused
{
    [[[self webView] webView] goForward];
}

- (NSNumber *)canGoBack:(id)unused
{
    return NUMBOOL([[[self webView] webView] canGoBack]);
}

- (NSNumber *)canGoForward:(id)unused
{
    return NUMBOOL([[[self webView] webView] canGoForward]);
}

- (void)startListeningToProperties:(id)args
{
    ENSURE_SINGLE_ARG(args, NSArray);
    
    for (id property in args) {
        ENSURE_TYPE(property, NSString);
        
        [[[self webView] webView] addObserver:self forKeyPath:property options:NSKeyValueObservingOptionNew context:NULL];
    }
    
    genericProperties = args;
}

- (void)stopListeningToProperties:(id)args
{
    ENSURE_SINGLE_ARG(args, NSArray);
    
    for (id property in args) {
        ENSURE_TYPE(property, NSString);
        
        [[[self webView] webView] removeObserver:self forKeyPath:property];
    }
    
    genericProperties = nil;
}

- (void)evalJS:(id)args
{
    NSString *code = nil;
    KrollCallback *callback = nil;
    
    ENSURE_ARG_AT_INDEX(code, args, 0, NSString);
    ENSURE_ARG_OR_NIL_AT_INDEX(callback, args, 1, KrollCallback);

    [[[self webView] webView] evaluateJavaScript:code completionHandler:^(id result, NSError *error) {
        if (!callback) {
            return;
        }
        
        NSMutableDictionary *event = [NSMutableDictionary dictionaryWithDictionary:@{
            @"result": result ?: [NSNull null],
            @"success": NUMBOOL(error == nil)
        }];
        
        if (error) {
            [event setObject:[error localizedDescription] forKey:@"error"];
        }
        
        [callback call:[[NSArray alloc] initWithObjects:&event count:1] thisObject:self];
    }];
}

- (NSString *)evalJSSync:(id)args
{
    NSString *code = nil;
    
    __block NSString *resultString = nil;
    __block BOOL finishedEvaluation = NO;
    
    ENSURE_ARG_AT_INDEX(code, args, 0, NSString);
    
    [[[self webView] webView] evaluateJavaScript:code completionHandler:^(id result, NSError *error) {
        resultString = NULL_IF_NIL(result);
        finishedEvaluation = YES;
    }];
    
    while (!finishedEvaluation) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
    
    return resultString;
}

#if __IPHONE_11_0
- (void)takeSnapshot:(id)args
{
    if ([TiUtils isIOSVersionOrGreater:@"11.0"]) {
        DebugLog(@"[ERROR] The \"takeSnapshot\" method is only available on iOS 11 and later.");
        return;
    }
        
    KrollCallback *callback = (KrollCallback *)[args objectAtIndex:0];
    ENSURE_TYPE(callback, KrollCallback);
    
    [[[self webView] webView] takeSnapshotWithConfiguration:nil
                                          completionHandler:^(UIImage *snapshotImage, NSError *error) {
                                              if (error != nil) {
                                                  [callback call:@[@{@"success": NUMBOOL(NO), @"error": error.localizedDescription}] thisObject:self];
                                                  return;
                                              }
                                              
                                              [callback call:@[@{@"success": NUMBOOL(YES),@"snapshot": [[TiBlob alloc] initWithImage:snapshotImage]}] thisObject:self];
                                          }];
}
#endif

#pragma mark Utilities

+ (NSDictionary *)_dictionaryFromBackForwardItem:(WKBackForwardListItem *)item
{
    return @{@"url": item.URL.absoluteString, @"initialUrl": item.initialURL.absoluteString, @"title": item.title};
}

#pragma mark Generic KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    for (NSString *property in genericProperties) {
        if ([self _hasListeners:property] && [keyPath isEqualToString:property] && object == [[self webView] webView]) {
            [self fireEvent:property withObject:@{@"value": NULL_IF_NIL([[[self webView] webView] valueForKey:property])}];
            return;
        }
    }
    
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

@end
