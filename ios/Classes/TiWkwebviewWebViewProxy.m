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

- (TiWkwebviewWebView *)webView
{
    return (TiWkwebviewWebView *)self.view;
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
        [backList addObject:[TiWkwebviewWebViewProxy dictionaryFromBackForwardItem:item]];
    }
    
    for (WKBackForwardListItem *item in list.forwardList) {
        [forwardList addObject:[TiWkwebviewWebViewProxy dictionaryFromBackForwardItem:item]];
    }
    
    return @{
        @"currentItem": [TiWkwebviewWebViewProxy dictionaryFromBackForwardItem:[list currentItem]],
        @"backItem": [TiWkwebviewWebViewProxy dictionaryFromBackForwardItem:[list backItem]],
        @"forwardItem": [TiWkwebviewWebViewProxy dictionaryFromBackForwardItem:[list forwardItem]],
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

- (id)allowsPictureInPictureMediaPlaybacke
{
    NUMBOOL([[[[self webView] webView] configuration] allowsPictureInPictureMediaPlayback]);
}

#pragma mark Methods

- (id)isLoading:(id)unused
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

- (id)canGoBack:(id)unused
{
    return NUMBOOL([[[self webView] webView] canGoBack]);
}

- (id)canGoForward:(id)unused
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

#pragma mark Utilities

+ (NSDictionary *)dictionaryFromBackForwardItem:(WKBackForwardListItem *)item
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
