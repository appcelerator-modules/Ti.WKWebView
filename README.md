# Ti.WKWebView 
[![License](http://hans-knoechel.de/shields/shield-license.svg?v=2)](./LICENSE)  [![Support](http://hans-knoechel.de/shields/shield-slack.svg?v=3)](http://tislack.org)

## Summary
Ti.WKWebView is an open source project to support the `WKWebView` API with Titanium.

## Requirements
- Titanium SDK 5.0.0 or later
- iOS 9+
- Xcode 7+

## Download + Setup

### Download
* [Stable release](https://github.com/appcelerator-modules/ti.wkwebview/releases)
* [![gitTio](http://hans-knoechel.de/shields/shield-gittio.svg)](http://gitt.io/component/ti.wkwebview)

### Setup
Unpack the module and place it inside the `modules/iphone` folder of your project.
Edit the iOS and modules section of your `tiapp.xml` file to include this module:
```xml
<ios>
  <min-ios-ver>9.0</min-ios-ver>
</ios>
<modules>
  <module>ti.wkwebview</module>
</modules>
```

## Features

### API's

| Name | Example|
|------|--------|
| WebView | `WK.createWebView(args)` |
| ProcessPool | `WK.createProcessPool()` |
| Configuration | `WK.createConfiguration()` |

### WebView

#### Properties

| Name | Type |
|------|------|
| disableBounce | Boolean |
| scalePageToFit | Boolean |
| disableZoom | Boolean |
| allowsBackForwardNavigationGestures | Boolean |
| allowsLinkPreview | Boolean |
| scrollsToTop | Boolean |
| disableContextMenu | Boolean |
| userAgent | String |
| url | String |
| data | Ti.Blob, Ti.File |
| html | String |
| title | String |
| progress | Double |
| backForwardList | Object |
| ignoreSslError | Boolean |
| basicAuhentication | Object<br/>- username (String)<br/>- password (String)<br/>- persistence (CREDENTIAL_PERSISTENCE_*) |
| cachePolicy | CACHE_POLICY_* |
| timeout | Double |
| selectionGranularity | SELECTION_GRANULARITY_* |
| allowedURLSchemes | Array\<String\> |
| touchEnabled | Boolean |
| willHandleTouches | Boolean |
| requestHeaders | Object<String, Any> |

#### Methods

| Name | Parameter | Return |
|------|-----------|--------|
| stopLoading | - | Void |
| reload | - | Void |
| goBack | - | Void |
| goForward | - | Void |
| canGoBack | - | Boolean |
| canGoForward | - | Boolean |
| isLoading | - | Boolean |
| evalJS | Code (String), Callback (Function) | Void |
| evalJSSync | Code (String) | String |
| startListeningToProperties | Array<String> | Void |
| stopListeningToProperties | Array<String> | Void |
| fireEvent | Name (String), Payload (Object) | Void |
| addEventListener | Name (String), Callback (Function) | Void |
| removeEventListener | Name (String), Callback (Function) | Void |
| takeSnapshot * | Callback (Function) | Void |
| addUserScript | Object: source (String), injectionTime (INJECTION_TIME_*), mainFrameOnly (Boolean | Void |
| removeAllUserScripts | - | Void |
| addScriptMessageHandler | Name (String) | Void |
| removeScriptMessageHandler | Name (String) | Void |

* Available on iOS 11.0+

#### Events

| Name | Properties |
|------|------------|
| message | name, body, url, isMainFrame |
| progress | value, url |
| beforeload | url, title |
| load | url, title |
| redirect | url, title |
| error | url, title, error |
| handleurl | url |

#### Constants

| Name | Property |
|------|----------|
| CREDENTIAL_PERSISTENCE_NONE | basicAuthentication.persistence |
| CREDENTIAL_PERSISTENCE_FOR_SESSION | basicAuthentication.persistence |
| CREDENTIAL_PERSISTENCE_PERMANENT | basicAuthentication.persistence |
| CREDENTIAL_PERSISTENCE_SYNCHRONIZABLE | basicAuthentication.persistence |
| AUDIOVISUAL_MEDIA_TYPE_NONE | mediaTypesRequiringUserActionForPlayback |
| AUDIOVISUAL_MEDIA_TYPE_AUDIO | mediaTypesRequiringUserActionForPlayback |
| AUDIOVISUAL_MEDIA_TYPE_VIDEO | mediaTypesRequiringUserActionForPlayback |
| AUDIOVISUAL_MEDIA_TYPE_ALL | mediaTypesRequiringUserActionForPlayback |
| CACHE_POLICY_USE_PROTOCOL_CACHE_POLICY | cachePolicy |
| CACHE_POLICY_RELOAD_IGNORING_LOCAL_CACHE_DATA | cachePolicy |
| CACHE_POLICY_RETURN_CACHE_DATA_ELSE_LOAD | cachePolicy |
| CACHE_POLICY_RETURN_CACHE_DATA_DONT_LOAD | cachePolicy |
| SELECTION_GRANULARITY_AUTOMATIC | selectionGranularity |
| SELECTION_GRANULARITY_CHARACTER | selectionGranularity |
| ACTION_POLICY_CANCEL | handleurl (Event) |
| ACTION_POLICY_ALLOW | handleurl (Event) |
| INJECTION_TIME_DOCUMENT_START | addUserScript.injectionTime |
| INJECTION_TIME_DOCUMENT_END | addUserScript.injectionTime |

#### WebView <-> App Communication
You can send data from the Web View to your native app by posting messages like this:
```javascript
window.webkit.messageHandlers.Ti.postMessage({message: 'Titanium rocks!'},'*');
```
Please note that you should use the `Ti` message handler to ensure the `message` event is 
triggered. This also ensures that your app does not receive unwanted messages by remote pages.

After sending the message from your HTML file, it will trigger the `message` event with the 
following event keys:
- url (The url of the triggered message)
- body (The message body. In this case: `{message: 'Titanium rocks'}`
- name (The name of the message. In this case: 'Ti')
- isMainFrame (A boolean determing if the messsage was sent from the main-frame)

For sending messages from the app to the Web View, use `evalJS` to call your JS methods like this:
```javascript
webView.evalJS('myJSMethod();');
```
Check out the example file for sending and receiving message back and forth.

**Note 1**: Since 2.3.0, this module also supports synchronous communication via `evalJSSync`.
Instead of `evalJS`, it takes only one parameter (the code to evaluate) and no callback. Instead,
it returns the JavaScript evaluation result directly. While we understand there might be use-cases for
this functionality, we highly recommend to use asynchronous communication instead, since synchronous method
calls with block the user interface and may cause in an app-termination for long-running evaluations.

**Note 2**: Since 2.4.0, this modules also supports Ti.App-like events that allows the developer to fire events
and add event-listeners to ease the communication between the app and the web-view. These are:
  * fireEvent
  * addEventListener
  * removeEventListener
Different to the Ti.App events, these ones are fired on the top-level module instance. See this example for details:
```js
var WK = require('ti.wkwebview');

// Fire event
WK.fireEvent('myEvent', { message: 'Titanium rocks!' });

// Listen to events
WK.addEventListener('myEvent', function(e) { ... });
```
The above events can be used on the JS-side as well. Here is an example on how to use them in your HTML file (ensure that there is no concurring WK variable):
```html
<!DOCTYPE html>
<html>
    <head>
        <title>Local HTML</title>
    </head>
    <body>
        <p>Hello world!</p>
        <script type=\"text/javascript\">
            // Listen to the native Titanium event
            WK.addEventListener('testEvent', function(e) {
                // Fire back an event to the native Titanium app
                WK.fireEvent('testEventBack', {
                    message: 'It worked!'
                });
            });
        </script>
    </body>
</html>
```

#### Saving Images

If you want to allow users to browse the internet (e.g. by using a remote site), ensure to include the
`NSPhotoLibraryAddUsageDescription` key in your tiapp.xml. Different to the `UIWebView` and its `Ti.UI.WebView`
implementation, the `WKWebView` is more configurable but require the developer to act more carefully. 

#### Inter-App Communication
For using the URL schemes `mailto`, `tel`, `sms` and `itms-services` you only have to set the `allowedURLSchemes` property. Other URL schemes (i.e. `fb`) additionally need the corresponding `LSApplicationQueriesSchemes` key in the iOS plist dictionary of your `tiapp.xml`:
```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>fb</string>
</array>
```

#### Generic Property Observing
You can listen to changes in some of the native properties (see the native KVO-capability). Example:
```js
// Start listening for changes
webView.startListeningToProperties(['title']);

// Add an event listener for the change
webView.addEventListener('title', function(e) {
    // Check for e.value
});

// Remove listening to changes (remove the event listener as well to keep it more clean)
webView.stopListeningToProperties(['title']);
```

### Configuration

Use the configuration API to configure the initial web-view. This property can only be set when creating the 
webview and will be ignored when set afterwards. Example:
```js
var WK = require('ti.wkwebview');

var config = WK.createConfiguration({
    allowsPictureInPictureMediaPlaback: true
});

var webView = WK.createWebView({
    configuration: config
});
```

#### Properties

| Name | Type |
|------|------|
| mediaTypesRequiringUserActionForPlayback | AUDIOVISUAL_MEDIA_TYPE_* |
| suppressesIncrementalRendering | Boolean |
| preferences | Object<br/>- minimumFontSize (Double)<br/>- javaScriptEnabled (Boolean)<br/>- javaScriptCanOpenWindowsAutomatically (Boolean) |
| allowsInlineMediaPlayback | Boolean |
| allowsAirPlayMediaPayback | Boolean |
| allowsPictureInPictureMediaPlaback | Boolean |
| processPool | ProcessPool |

### Process Pool

Use process pools to share cookies between web views. Process pools do not take arguments, just pass the same 
reference to multiple web views. Example:
```js
var WK = require('ti.wkwebview');

var pool = WK.createProcessPool();

var config1 = WK.createConfiguration({
    processPool: pool
});

var config2 = WK.createConfiguration({
    processPool: pool
});

var firstWebView = WK.createWebView({
    configuration: config1
});

var secondWebView = WK.createWebView({
    configuration: config2
});
```

### Handle custom URL-schemes

- The custom url-scheme has to be registered in the `allowedURLSchemes` array-property
- Passes the `url` for a custom url-scheme
- The event is introduced because iOS 10+ causes issues for some custom url-schemes and forwarding the url 
  in an event is a simpler short term solution than implementing the `WKURLSchemeHandler` which is iOS 11+ only.

```js
// Add an event listener to listen for a custom URL-scheme
webView.addEventListener('handleurl', function(e) {
  var handler = e.handler;

  Ti.Platform.openURL(e.url);
  handler.invoke(WK.ACTION_POLICY_CANCEL); // ACTION_POLICY_CANCEL or ACTION_POLICY_ALLOW
});
```

## Author
Hans Knoechel ([@hansemannnn](https://twitter.com/hansemannnn) / [Web](http://hans-knoechel.de)) for Axway Appcelerator

## License
Apache 2.0

## Contributing
Code contributions are greatly appreciated, please submit a new [pull request](https://github.com/appcelerator-modules/ti.wkwebview/pull/new/master)!
