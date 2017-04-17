# Ti.WKWebView 
[![Build Status](https://travis-ci.org/appcelerator-modules/Ti.WKWebView.svg?branch=master)](https://travis-ci.org/appcelerator-modules/Ti.WKWebView) [![License](http://hans-knoechel.de/shields/shield-license.svg)](./LICENSE)  [![Support](http://hans-knoechel.de/shields/shield-slack.svg)](http://tislack.org)

Summary
---------------
Ti.WKWebView is an open source project to support the `WKWebView` API with Titanium.

Requirements
---------------
- Titanium Mobile SDK 5.0.0.GA or later
- iOS 9 or later
- Xcode 7.0 or later

Download + Setup
---------------

### Download
* [Stable release](https://github.com/appcelerator-modules/ti.wkwebview/releases)
* [![gitTio](http://hans-knoechel.de/shields/shield-gittio.svg)](http://gitt.io/component/ti.wkwebview)

### Setup
Unpack the module and place it inside the `modules/iphone` folder of your project.
Edit the modules section of your `tiapp.xml` file to include this module:
```xml
<modules>
    <module>ti.wkwebview</module>
</modules>
```

Features
---------------
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
| allowsBackForwardNavigationGestures | Boolean |
| allowsLinkPreview | Boolean |
| scrollsToTop | Boolean |
| disableContextMenu | Boolean |
| userAgent | String|
| url | String |
| data | Ti.Blob, Ti.File |
| html | Boolean |
| title | Boolean |
| progress | Double |
| backForwardList | Object |
| ignoreSslError | Boolean |
| basicAuhentication | Object<br/>- username (String)<br/>- password (String)<br/>- persistence (CREDENTIAL_PERSISTENCE_*) |
| cachePolicy | CACHE_POLICY_* |
| timeout | Double |
| selectionGranularity | SELECTION_GRANULARITY_* |

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
| evalJS | Code (String), Callback (Function) | Void|
| startListeningToProperties | Properties (Array<String>) | Void |
| stopListeningToProperties | Properties (Array<String>) | Void |

#### Events

| Name | Properties |
|------|------------|
| message | name, body, url, isMainFrame |
| progress | value, url |
| beforeload | url, title |
| load | url, title |
| redirect | url, title |
| error | url, title, error |

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

Author
---------------
Hans Knoechel ([@hansemannnn](https://twitter.com/hansemannnn) / [Web](http://hans-knoechel.de)) for Appcelerator

License
---------------
Apache 2.0

Contributing
---------------
Code contributions are greatly appreciated, please submit a new [pull request](https://github.com/appcelerator-modules/ti.wkwebview/pull/new/master)!
