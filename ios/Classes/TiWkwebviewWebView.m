/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-present by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiWkwebviewModule.h"
#import "TiWkwebviewWebView.h"
#import "TiWkwebviewWebViewProxy.h"
#import "TiWkwebviewConfigurationProxy.h"
#import "TiWkwebviewDecisionHandlerProxy.h"

#import "TiFilesystemFileProxy.h"
#import "TiApp.h"
#import "TiCallbackManager.h"
#import "SBJSON.h"

extern NSString * const kTiWKFireEvent;
extern NSString * const kTiWKAddEventListener;
extern NSString * const kTiWKEventCallback;

static NSString * const baseInjectScript = @"Ti._hexish=function(a){var r='';var e=a.length;var c=0;var h;while(c<e){h=a.charCodeAt(c++).toString(16);r+='\\\\u';var l=4-h.length;while(l-->0){r+='0'};r+=h}return r};Ti._bridgeEnc=function(o){return'<'+Ti._hexish(o)+'>'};Ti._JSON=function(object,bridge){var type=typeof object;switch(type){case'undefined':case'function':case'unknown':return undefined;case'number':case'boolean':return object;case'string':if(bridge===1)return Ti._bridgeEnc(object);return'\"'+object.replace(/\"/g,'\\\\\"').replace(/\\n/g,'\\\\n').replace(/\\r/g,'\\\\r')+'\"'}if((object===null)||(object.nodeType==1))return'null';if(object.constructor.toString().indexOf('Date')!=-1){return'new Date('+object.getTime()+')'}if(object.constructor.toString().indexOf('Array')!=-1){var res='[';var pre='';var len=object.length;for(var i=0;i<len;i++){var value=object[i];if(value!==undefined)value=Ti._JSON(value,bridge);if(value!==undefined){res+=pre+value;pre=', '}}return res+']'}var objects=[];for(var prop in object){var value=object[prop];if(value!==undefined){value=Ti._JSON(value,bridge)}if(value!==undefined){objects.push(Ti._JSON(prop,bridge)+': '+value)}}return'{'+objects.join(',')+'}'};";

@implementation TiWkwebviewWebView

#pragma mark Internal API's

- (WKWebView *)webView
{
    if (_webView == nil) {
        TiWkwebviewConfigurationProxy *configProxy = [[self proxy] valueForKey:@"configuration"];
        WKWebViewConfiguration *config = configProxy ? [configProxy configuration] : [[WKWebViewConfiguration alloc] init];
        WKUserContentController *controller = [[WKUserContentController alloc] init];

        [controller addUserScript:[TiWkwebviewWebView userScriptTitaniumInjection]];
        [controller addUserScript:[self userScriptTitaniumInjectionForAppEvent]];
        [controller addScriptMessageHandler:self name:@"TiApp"];
        [controller addScriptMessageHandler:self name:@"Ti"];

        [config setUserContentController:controller];
        willHandleTouches = [TiUtils boolValue:[[self proxy] valueForKey:@"willHandleTouches"] def:YES];
        
        _webView = [[WKWebView alloc] initWithFrame:[self bounds] configuration:config];
        
        [_webView setUIDelegate:self];
        [_webView setNavigationDelegate:self];
        [_webView setContentMode:[self contentModeForWebView]];
        [_webView setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
        
        // KVO for "progress" event
        [_webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:NULL];
        
        [self addSubview:_webView];
    }
    
    return _webView;
}

- (void)registerNotificationCenter
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didFireEvent:) name:kTiWKFireEvent object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didAddEventListener:) name:kTiWKAddEventListener object:nil];
}

- (void)didFireEvent:(NSNotification *)notification
{
    NSDictionary *event = [notification userInfo];
    
    NSString *name = [event objectForKey:@"name"];
    NSDictionary *payload = [event objectForKey:@"payload"];
    
    NSError *jsonError;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload
                                                       options:(NSJSONWritingOptions)0
                                                         error:&jsonError];
    
    if (!jsonData) {
        NSLog(@"[ERROR] Error firing event '%@': %@", name, jsonError.localizedDescription);
        return;
    } else {
        NSString *jsonPayload = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        
        [[self webView] evaluateJavaScript:[NSString stringWithFormat:@"WK.fireEvent('%@', %@)", name, jsonPayload]
                         completionHandler:^(id result, NSError *error) {
                             if (error != nil) {
                                 NSLog(@"[ERROR] Error firing event '%@': %@", name, error.localizedDescription);
                             }
                         }];
    }
}

- (void)didAddEventListener:(NSNotification *)notification
{
    NSDictionary *event = [notification userInfo];
    
    NSString *name = [event objectForKey:@"name"];
    KrollCallback *callback = [event objectForKey:@"callback"];

    [[TiCallbackManager sharedInstance] addCallback:callback withName:name];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *view = [super hitTest:point withEvent:event];
    if (([self hasTouchableListener]) && willHandleTouches) {
        UIView *superView = [view superview];
        UIView *parentSuperView = [superView superview];
        
        if ((view == [self webView]) || (superView == [self webView]) || (parentSuperView == [self webView])) {
            return self;
        }
    }
    
    return view;
}

-(void)setWillHandleTouches_:(id)value
{
    ENSURE_TYPE(value, NSNumber);
    
    [[self proxy] replaceValue:value forKey:@"willHandleTouches" notification:NO];
    willHandleTouches = [TiUtils boolValue:value def:YES];
}

- (void)fireEvent:(id)listener withObject:(id)obj remove:(BOOL)yn thisObject:(id)thisObject_
{
  if (_webView != nil) {
    NSDictionary *event = (NSDictionary *)obj;
    NSString *name = [event objectForKey:@"type"];
    NSString *js = [NSString stringWithFormat:@"Ti.App._dispatchEvent('%@',%@,%@);", name, listener, [TiUtils jsonStringify:event]];
    [_webView evaluateJavaScript:js
                     completionHandler:^(id result, NSError *error) {
                       if (error != nil) {
                         NSLog(@"[ERROR] Error firing event '%@': %@", name, error.localizedDescription);
                       }
                     }];
  }
}

#pragma mark Public API's

- (void)setUrl_:(id)value
{
    ENSURE_TYPE(value, NSString);
    [[self proxy] replaceValue:value forKey:@"url" notification:NO];
    
    if ([[self webView] isLoading]) {
        [[self webView] stopLoading];
    }
    
    if ([[self proxy] _hasListeners:@"beforeload"]) {
        [[self proxy] fireEvent:@"beforeload" withObject:@{@"url": [TiUtils stringValue:value]}];
    }
    
    // Handle remote URL's
    if ([value hasPrefix:@"http"] || [value hasPrefix:@"https"]) {
        [self loadRequestWithURL:[NSURL URLWithString:[TiUtils stringValue:value]]];
    // Handle local URL's (WiP)
    } else {
        NSString *path = [[TiUtils toURL:value proxy:self.proxy] absoluteString];
        [[self webView] loadFileURL:[NSURL fileURLWithPath:path]
            allowingReadAccessToURL:[NSURL fileURLWithPath:[path stringByDeletingLastPathComponent]]];
    }
}

- (void)setBackgroundColor_:(id)value
{
    ENSURE_TYPE(value, NSString);
    [[self proxy] replaceValue:value forKey:@"backgroundColor" notification:NO];
   
    [[self webView] setOpaque:NO];
    [[self webView] setBackgroundColor:[[TiUtils colorValue:value] color]];
}

- (void)setData_:(id)value
{
    [[self proxy] replaceValue:value forKey:@"data" notification:NO];
    
    if ([[self webView] isLoading]) {
        [[self webView] stopLoading];
    }
    
    if ([[self proxy] _hasListeners:@"beforeload"]) {
        [[self proxy] fireEvent:@"beforeload" withObject:@{@"url": [[NSBundle mainBundle] bundlePath], @"data": [TiUtils stringValue:value]}];
    }
    
    NSData *data = nil;
    
    if ([value isKindOfClass:[TiBlob class]]) {
        data = [(TiBlob *)value data];
    } else if ([value isKindOfClass:[TiFile class]]) {
#ifdef USE_TI_FILESYSTEM
        data = [[(TiFilesystemFileProxy *)value blob] data];
#endif
    } else {
        NSLog(@"[ERROR] Ti.UI.iOS.WebView.data can only be a TiBlob or TiFile object, was %@", [(TiProxy *)value apiName]);
    }
    
    [[self webView] loadData:data
                    MIMEType:[TiWkwebviewWebView mimeTypeForData:data]
       characterEncodingName:@"UTF-8" // TODO: Support other character-encodings as well
                     baseURL:[[NSBundle mainBundle] resourceURL]];
}

- (void)setHtml_:(id)value
{
    ENSURE_TYPE(value, NSString);
    [[self proxy] replaceValue:value forKey:@"html" notification:NO];
   
    NSString *content = [TiUtils stringValue:value];

    if ([[self webView] isLoading]) {
        [[self webView] stopLoading];
    }
    
    if ([[self proxy] _hasListeners:@"beforeload"]) {
        [[self proxy] fireEvent:@"beforeload" withObject:@{@"url": [[NSBundle mainBundle] bundlePath], @"html": content}];
    }
    
    [[self webView] loadHTMLString:content baseURL:nil];
}

- (void)setDisableBounce_:(id)value
{
    [[self proxy] replaceValue:[value isEqual: @1] ? @0 : @1 forKey:@"disableBounce" notification:NO];
    [[[self webView] scrollView] setBounces:![TiUtils boolValue:value]];
}

- (void)setScrollsToTop_:(id)value
{
    [[self proxy] replaceValue:value forKey:@"scrollsToTop" notification:NO];
    [[[self webView] scrollView] setScrollsToTop:[TiUtils boolValue:value def:YES]];
}

- (void)setAllowsBackForwardNavigationGestures_:(id)value
{
    [[self proxy] replaceValue:value forKey:@"allowsBackForwardNavigationGestures" notification:NO];
    [[self webView] setAllowsBackForwardNavigationGestures:[TiUtils boolValue:value def:NO]];
}

- (void)setUserAgent_:(id)value
{
    [[self proxy] replaceValue:value forKey:@"userAgent" notification:NO];
    [[self webView] setCustomUserAgent:[TiUtils stringValue:value]];
}

-(void)setDisableZoom_:(id)value
{
    ENSURE_TYPE(value, NSNumber);

    BOOL disableZoom = [TiUtils boolValue:value];
    
    if (disableZoom) {
        WKUserContentController *controller = [[[self webView] configuration] userContentController];
        [controller addUserScript:[TiWkwebviewWebView userScriptDisableZoom]];
    }
}

-(void)setScalePageToFit_:(id)value
{
    ENSURE_TYPE(value, NSNumber);
    
    BOOL scalePageToFit = [TiUtils boolValue:value];
    BOOL disableZoom = [TiUtils boolValue:[[self proxy] valueForKey: @"disableZoom"]];
    
    if (scalePageToFit && !disableZoom) {
        WKUserContentController *controller = [[[self webView] configuration] userContentController];
        [controller addUserScript:[TiWkwebviewWebView userScriptScalePageToFit]];
    }
}

-(void)setDisableContextMenu_:(id)value
{
    ENSURE_TYPE(value, NSNumber);

    BOOL disableContextMenu = [TiUtils boolValue:value];
    
    if (disableContextMenu == YES) {
        WKUserContentController *controller = [[[self webView] configuration] userContentController];
        [controller addUserScript:[TiWkwebviewWebView userScriptDisableContextMenu]];
    }
}


#pragma mark Utilities

- (void)loadRequestWithURL:(NSURL *)url
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:[TiUtils intValue:[[self proxy] valueForKey:@"cachePolicy"] def:NSURLRequestUseProtocolCachePolicy]
                                                       timeoutInterval:[TiUtils doubleValue:[[self proxy] valueForKey:@"timeout"] def:60]];

    // Set request headers
    NSDictionary<NSString *, id> *requestHeaders = [[self proxy] valueForKey:@"requestHeaders"];
    
    if (requestHeaders != nil) {
        for (NSString *key in requestHeaders) {
            [request setValue:requestHeaders[key] forHTTPHeaderField:key];
        }

        // Inject user-agent by using the obj-c nullability to set and reset it
        NSString *userAgent = requestHeaders[@"User-Agent"];
        [[self webView] setCustomUserAgent:userAgent];
    }

    [[self webView] loadRequest:request];
}

+ (WKUserScript *)userScriptScalePageToFit
{
    NSString *source = @"var meta = document.createElement('meta'); \
    meta.setAttribute('name', 'viewport'); \
    meta.setAttribute('content', 'width=device-width, initial-scale=1, maximum-scale=1'); \
    document.getElementsByTagName('head')[0].appendChild(meta);";
    
    return [[WKUserScript alloc] initWithSource:source injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
}

+ (WKUserScript *)userScriptTitaniumInjection
{
    NSString *source = @"var callbacks = {}; var WK = { \
                            fireEvent: function(name, payload) { \
                                var _payload = payload; \
                                if (typeof payload === 'string') { \
                                    _payload = JSON.parse(payload); \
                                } \
                                if (callbacks[name]) { \
                                    callbacks[name](_payload); \
                                } \
                                window.webkit.messageHandlers.Ti.postMessage({name: name, payload: _payload},'*'); \
                            }, \
                            addEventListener: function(name, callback) { \
                                callbacks[name] = callback; \
                            }, \
                            removeEventListener: function(name, callback) { \
                                delete callbacks[name]; \
                            } \
                        }";
    
    return [[WKUserScript alloc] initWithSource:source injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
}

- (WKUserScript *)userScriptTitaniumInjectionForAppEvent
{
    if (_pageToken == nil) {
        _pageToken = [NSString stringWithFormat:@"%lu", (unsigned long)[self hash]];
        [(TiWkwebviewWebViewProxy *)self.proxy setPageToken:_pageToken];
    }

    NSString *source = @"var callbacks = {}; var Ti = {}; Ti.pageToken = %@; \
                        Ti._listener_id = 1; Ti._listeners={}; %@\
                        Ti.App = { \
                            fireEvent: function(name, payload) { \
                                var _payload = payload; \
                                if (typeof payload === 'string') { \
                                    _payload = JSON.parse(payload); \
                                } \
                                if (callbacks[name]) { \
                                    callbacks[name](_payload); \
                                } \
                                window.webkit.messageHandlers.TiApp.postMessage({name: name, payload: _payload, method: 'fireEvent'},'*'); \
                            }, \
                            addEventListener: function(name, callback) { \
                                callbacks[name] = callback; \
                                var listeners=Ti._listeners[name]; \
                                if(typeof(listeners)=='undefined'){ \
                                    listeners=[];Ti._listeners[name]=listeners} \
                                    var newid=Ti.pageToken+Ti._listener_id++; \
                                    listeners.push({callback:callback,id:newid});\
                                    window.webkit.messageHandlers.TiApp.postMessage({name: name, method: 'addEventListener', callback: Ti._JSON({name:name, id:newid},1)},'*'); \
                            }, \
                            removeEventListener: function(name, callback) { \
                                var listeners=Ti._listeners[name]; \
                                if(listeners){ \
                                    for(var c=0;c<listeners.length;c++){ \
                                        var entry=listeners[c]; \
                                        if(entry.callback==fn){ \
                                            listeners.splice(c,1);\
                                            window.webkit.messageHandlers.TiApp.postMessage({name: name, method: 'removeEventListener', callback: Ti._JSON({name:name, id:entry.id},1)},'*'); \
                                delete callbacks[name]; break}}}\
                            }, \
                            _dispatchEvent: function(type,evtid,evt){ \
                                var listeners=Ti._listeners[type]; \
                                if(listeners){ \
                                    for(var c=0;c<listeners.length;c++){ \
                                        var entry=listeners[c]; \
                                        if(entry.id==evtid){ \
                                            entry.callback.call(entry.callback,evt) \
                        }}}}}; \
                    Ti.API = { \
                        debug: function(message) { \
                            window.webkit.messageHandlers.TiApp.postMessage({name:'debug', method: 'log', callback: Ti._JSON({level:'debug', message:message},1)},'*'); \
                        }, \
                        error: function(message) { \
                            window.webkit.messageHandlers.TiApp.postMessage({name:'error', method: 'log', callback: Ti._JSON({level:'error', message:message},1)},'*'); \
                        }, \
                        info: function(message){ \
                            window.webkit.messageHandlers.TiApp.postMessage({name:'info', method: 'log', callback: Ti._JSON({level:'info', message:message},1)},'*'); \
                        }, \
                        fatal: function(message){ \
                            window.webkit.messageHandlers.TiApp.postMessage({name:'fatal', method: 'log', callback: Ti._JSON({level:'fatal', message:message},1)},'*'); \
                        }, \
                        warn: function(message){ \
                            window.webkit.messageHandlers.TiApp.postMessage({name:'warn', method: 'log', callback: Ti._JSON({level:'warn', message:message},1)},'*'); \
                        }, \
    }; \
    ";

    NSString *sourceString = [NSString stringWithFormat:source, _pageToken, baseInjectScript];
    return [[WKUserScript alloc] initWithSource:sourceString injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
    }

+ (WKUserScript *)userScriptDisableZoom
{
    NSString *source = @"var meta = document.createElement('meta'); \
    meta.setAttribute('name', 'viewport'); \
    meta.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no'); \
    document.getElementsByTagName('head')[0].appendChild(meta);";
    
    return [[WKUserScript alloc] initWithSource:source injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
}

+ (WKUserScript *)userScriptDisableContextMenu
{
    NSString *source = @"var style = document.createElement('style'); \
    style.type = 'text/css'; \
    style.innerText = '*:not(input):not(textarea) { -webkit-user-select: none; -webkit-touch-callout: none; }'; \
    var head = document.getElementsByTagName('head')[0]; \
    head.appendChild(style);";
    
    return [[WKUserScript alloc] initWithSource:source
                                  injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                               forMainFrameOnly:YES];
}

+ (WKUserScript *)userScriptTitaniumJSEvaluationFromString:(NSString *)string
{
    return [[WKUserScript alloc] initWithSource:string
                                  injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                               forMainFrameOnly:YES];
}

- (NSString *)pathFromComponents:(NSArray *)args
{
    NSString * newPath;
    id first = [args objectAtIndex:0];
    
    if ([first hasPrefix:@"file://"]) {
        newPath = [[NSURL URLWithString:first] path];
    } else if ([first characterAtIndex:0]!='/') {
        newPath = [[[NSURL URLWithString:[self resourcesDirectory]] path] stringByAppendingPathComponent:[self resolveFile:first]];
    } else {
        newPath = [self resolveFile:first];
    }
    
    if ([args count] > 1) {
        for (int c = 1;c < [args count]; c++) {
            newPath = [newPath stringByAppendingPathComponent:[self resolveFile:[args objectAtIndex:c]]];
        }
    }
    
    return [newPath stringByStandardizingPath];
}

- (id)resolveFile:(id)arg
{
#ifdef USE_TI_FILESYSTEM
    if ([arg isKindOfClass:[TiFilesystemFileProxy class]]) {
        return [(TiFilesystemFileProxy *)arg path];
    }
#endif
    return [TiUtils stringValue:arg];
}

- (NSString *)resourcesDirectory
{
    return [NSString stringWithFormat:@"%@/",[[NSURL fileURLWithPath:[TiHost resourcePath] isDirectory:YES] path]];
}

// http://stackoverflow.com/a/32765708/5537752
+ (NSString *)mimeTypeForData:(NSData *)data
{
    uint8_t c;
    [data getBytes:&c length:1];
    
    switch (c) {
        case 0xFF:
            return @"image/jpeg";
            break;
        case 0x89:
            return @"image/png";
            break;
        case 0x47:
            return @"image/gif";
            break;
        case 0x49:
        case 0x4D:
            return @"image/tiff";
            break;
        case 0x25:
            return @"application/pdf";
            break;
        case 0xD0:
            return @"application/vnd";
            break;
        case 0x46:
            return @"text/plain";
            break;
        default:
            return @"application/octet-stream";
    }
    
    return nil;
}

#pragma mark Delegates


- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    BOOL isEvent = [[message body] isKindOfClass:[NSDictionary class]] && [[message body] objectForKey:@"name"];
    
    if (isEvent) {
        NSString *name = [[message body] objectForKey:@"name"];
        NSDictionary *payload = [[message body] objectForKey:@"payload"];
        
        if ([[TiCallbackManager sharedInstance] hasCallbackForName:name] && [message.name isEqualToString:@"Ti"]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:kTiWKEventCallback object:nil userInfo:@{@"name": name, @"payload": payload}];
            return;
        } else if ([message.name isEqualToString:@"TiApp"]) {
            NSString *callback = [[message body] objectForKey:@"callback"];
            
            SBJSON *decoder = [[SBJSON alloc] init];
            NSError *error = nil;
            NSDictionary *event = [decoder fragmentWithString:callback error:&error];
            
            NSString *method = [[message body] objectForKey:@"method"];
            NSString *moduleName = [method isEqualToString:@"log"] ? @"API" : @"App";

            id<TiEvaluator> context = [[(TiWkwebviewWebViewProxy *)self.proxy host] contextForToken:_pageToken];
            TiModule *tiModule = (TiModule *)[[(TiWkwebviewWebViewProxy *)self.proxy host] moduleNamed:moduleName context:context];
            [tiModule setExecutionContext:context];
            
            if ([method isEqualToString:@"fireEvent"]) {
                [tiModule fireEvent:name withObject:payload];
            } else if ([method isEqualToString:@"addEventListener"]) {
                id listenerid = [event objectForKey:@"id"];
                [tiModule addEventListener:[NSArray arrayWithObjects:name, listenerid, nil]];
            } else if ([method isEqualToString:@"removeEventListener"]) {
                id listenerid = [[message body] objectForKey:@"id"];
                [tiModule removeEventListener:[NSArray arrayWithObjects:name, listenerid, nil]];
            } else if ([method isEqualToString:@"log"]) {
                NSString *level = [event objectForKey:@"level"];
                NSString *message = [event objectForKey:@"message"];
                if ([tiModule respondsToSelector:@selector(log:)]) {
                    [tiModule performSelector:@selector(log:) withObject:@[level, message]];
                }
            }
            return;
        }
    }
    
    if ([[self proxy] _hasListeners:@"message"]) {
        [[self proxy] fireEvent:@"message" withObject:@{
            @"url": message.frameInfo.request.URL.absoluteString ?: [[NSBundle mainBundle] bundlePath],
            @"body": message.body,
            @"name": message.name,
            @"isMainFrame": NUMBOOL(message.frameInfo.isMainFrame),
        }];
    }
}

- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler
{
    id basicAuthentication = [[self proxy] valueForKey:@"basicAuthentication"];
    
    NSString *username = [TiUtils stringValue:@"username" properties:basicAuthentication];
    NSString *password = [TiUtils stringValue:@"password" properties:basicAuthentication];
    NSURLCredentialPersistence persistence = [TiUtils intValue:@"persistence" properties:basicAuthentication def:NSURLCredentialPersistenceNone];
    
    // Allow invalid certificates if specified
    if ([TiUtils boolValue:[[self proxy] valueForKey:@"ignoreSslError"] def:NO]) {
        NSURLCredential * credential = [[NSURLCredential alloc] initWithTrust:[challenge protectionSpace].serverTrust];
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
        
        return;
    }
    
    // Basic authentication
    if (!basicAuthentication && username && password) {
        completionHandler(NSURLSessionAuthChallengeUseCredential, [[NSURLCredential alloc] initWithUser:username
                                                                                               password:password
                                                                                            persistence:persistence]);
     // Default handling
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    if ([[self proxy] _hasListeners:@"load"]) {
        [[self proxy] fireEvent:@"load" withObject:@{@"url": webView.URL.absoluteString, @"title": webView.title}];
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    if ([[self proxy] _hasListeners:@"error"]) {
        [[self proxy] fireEvent:@"error" withObject:@{@"url": webView.URL.absoluteString, @"title": webView.title, @"error": [error localizedDescription]}];
    }
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    if ([[self proxy] _hasListeners:@"error"]) {
        NSURL *errorURL = webView.URL;

        if (errorURL.absoluteString == nil) {
            errorURL = [NSURL URLWithString:[[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]];
        }
        
        [[self proxy] fireEvent:@"error" withObject:@{@"url": NULL_IF_NIL(errorURL ? errorURL.absoluteString : nil), @"title": NULL_IF_NIL(webView.title), @"error": [error localizedDescription]}];
    }
}

- (void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation
{
    if ([[self proxy] _hasListeners:@"redirect"]) {
        [[self proxy] fireEvent:@"redirect" withObject:@{@"url": webView.URL.absoluteString, @"title": webView.title}];
    }
}

- (BOOL)webView:(WKWebView *)webView shouldPreviewElement:(WKPreviewElementInfo *)elementInfo
{
    return [TiUtils boolValue:[[self proxy] valueForKey:@"allowsLinkPreview"] def:NO];
}

- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:UIKitLocalizedString([TiUtils stringValue:[[self proxy] valueForKey:@"ok"]] ?: NSLocalizedString(@"OK", nil))
                                                        style:UIAlertActionStyleCancel
                                                      handler:^(UIAlertAction *action) {
                                                          completionHandler();
                                                      }]];
    
    [[TiApp app] showModalController:alertController animated:YES];
}

- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addAction:[UIAlertAction actionWithTitle:UIKitLocalizedString([TiUtils stringValue:[[self proxy] valueForKey:@"ok"]] ?: NSLocalizedString(@"OK", nil))
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *action) {
                                                          completionHandler(YES);
                                                      }]];
    
    [alertController addAction:[UIAlertAction actionWithTitle:UIKitLocalizedString([TiUtils stringValue:[[self proxy] valueForKey:@"cancel"]] ?: NSLocalizedString(@"Cancel", nil))
                                                        style:UIAlertActionStyleCancel
                                                      handler:^(UIAlertAction *action) {
                                                          completionHandler(NO);
                                                      }]];
    
    [[TiApp app] showModalController:alertController animated:YES];
}

- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * _Nullable))completionHandler
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
                                                                             message:prompt
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = defaultText;
    }];
    [alertController addAction:[UIAlertAction actionWithTitle:UIKitLocalizedString([TiUtils stringValue:[[self proxy] valueForKey:@"ok"]] ?: NSLocalizedString(@"OK", nil))
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *action) {
                                                          completionHandler(alertController.textFields.firstObject.text ?: defaultText);
                                                      }]];
    
    [alertController addAction:[UIAlertAction actionWithTitle:UIKitLocalizedString([TiUtils stringValue:[[self proxy] valueForKey:@"cancel"]] ?: NSLocalizedString(@"Cancel", nil))
                                                        style:UIAlertActionStyleCancel
                                                      handler:^(UIAlertAction *action) {
                                                          completionHandler(nil);
                                                      }]];
    
    [[TiApp app] showModalController:alertController animated:YES];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(nonnull WKNavigationAction *)navigationAction decisionHandler:(nonnull void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSArray<NSString *> *allowedURLSchemes = [[self proxy] valueForKey:@"allowedURLSchemes"];

    // Handle custom URL schemes
    if (allowedURLSchemes != nil && [allowedURLSchemes containsObject:navigationAction.request.URL.scheme]) {
        if ([[UIApplication sharedApplication] canOpenURL:navigationAction.request.URL]) {
            // Event to return url to Titanium in order to handle OAuth and more
            if ([[self proxy] _hasListeners:@"handleurl"]) {
                [[self proxy] fireEvent:@"handleurl" withObject:@{
                    @"url": [TiUtils stringValue:[[navigationAction request] URL]],
                    @"handler": [[TiWkwebviewDecisionHandlerProxy alloc] _initWithPageContext:[[self proxy] pageContext] andDecisionHandler:decisionHandler]
                }];
                return;
            } else {
                // DEPRECATED: Should use the "handleurl" event instead and call openURL on Ti.Platform.openURL instead
                DebugLog(@"[WARN] Please use the \"handleurl\" event together with \"allowedURLSchemes\" in Ti.WKWebView 2.5.0 and later.");
                DebugLog(@"[WARN] It returns both the \"url\" and \"handler\" property to open a URL and invoke the decision-handler.");

                [[UIApplication sharedApplication] openURL:navigationAction.request.URL];
                decisionHandler(WKNavigationActionPolicyCancel);
                return;
            }
        }
    }
    
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler
{
    NSDictionary<NSString *, id> *requestHeaders = [[self proxy] valueForKey:@"requestHeaders"];
    NSURL *requestedURL = navigationResponse.response.URL;

    // If we have request headers set, we do a little hack to persist them across different URL's,
    // which is not officially supportted by iOS.
    if (requestHeaders != nil && requestedURL != nil && ![requestedURL.absoluteString isEqualToString:_currentURL.absoluteString]) {
        _currentURL = requestedURL;
        decisionHandler(WKNavigationResponsePolicyCancel);
        [self loadRequestWithURL:_currentURL];
        return;
    }

    decisionHandler(WKNavigationResponsePolicyAllow);
}

static NSString *UIKitLocalizedString(NSString *string)
{
    NSBundle *UIKitBundle = [NSBundle bundleForClass:[UIApplication class]];
    return UIKitBundle ? [UIKitBundle localizedStringForKey:string value:string table:nil] : string;
}

#pragma mark Layout helper

- (void)setWidth_:(id)width_
{
    width = TiDimensionFromObject(width_);
    [self updateContentMode];
}

- (void)setHeight_:(id)height_
{
    height = TiDimensionFromObject(height_);
    [self updateContentMode];
}

- (void)updateContentMode
{
    if ([self webView] != nil) {
        [[self webView] setContentMode:[self contentModeForWebView]];
    }
}

- (UIViewContentMode)contentModeForWebView
{
    if (TiDimensionIsAuto(width) || TiDimensionIsAutoSize(width) || TiDimensionIsUndefined(width) ||
        TiDimensionIsAuto(height) || TiDimensionIsAutoSize(height) || TiDimensionIsUndefined(height)) {
        return UIViewContentModeScaleAspectFit;
    } else {
        return UIViewContentModeScaleToFill;
    }
}

- (void)frameSizeChanged:(CGRect)frame bounds:(CGRect)bounds
{
    for (UIView *child in [self subviews]) {
        [TiUtils setView:child positionRect:bounds];
    }
    
    [super frameSizeChanged:frame bounds:bounds];
}

- (CGFloat)contentWidthForWidth:(CGFloat)suggestedWidth
{
    if (autoWidth > 0) {
        //If height is DIP returned a scaled autowidth to maintain aspect ratio
        if (TiDimensionIsDip(height) && autoHeight > 0) {
            return roundf(autoWidth * height.value / autoHeight);
        }
        return autoWidth;
    }
    
    CGFloat calculatedWidth = TiDimensionCalculateValue(width, autoWidth);
    if (calculatedWidth > 0) {
        return calculatedWidth;
    }
    
    return 0;
}

- (CGFloat)contentHeightForWidth:(CGFloat)width_
{
    if (width_ != autoWidth && autoWidth>0 && autoHeight > 0) {
        return (width_ * autoHeight/autoWidth);
    }
    
    if (autoHeight > 0) {
        return autoHeight;
    }
    
    CGFloat calculatedHeight = TiDimensionCalculateValue(height, autoHeight);
    if (calculatedHeight > 0) {
        return calculatedHeight;
    }
    
    return 0;
}

- (UIViewContentMode)contentMode
{
    if (TiDimensionIsAuto(width) || TiDimensionIsAutoSize(width) || TiDimensionIsUndefined(width) ||
        TiDimensionIsAuto(height) || TiDimensionIsAutoSize(height) || TiDimensionIsUndefined(height)) {
        return UIViewContentModeScaleAspectFit;
    } else {
        return UIViewContentModeScaleToFill;
    }
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"estimatedProgress"] && object == [self webView]) {
        if ([[self proxy] _hasListeners:@"progress"]) {
            [[self proxy] fireEvent:@"progress" withObject:@{
                @"value": NUMDOUBLE([[self webView] estimatedProgress]),
                @"url": [[[self webView] URL] absoluteString] ?: @""
            }];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
