//******************************************************************************
//
// Copyright (c) 2015 Microsoft Corporation. All rights reserved.
//
// This code is licensed under the MIT License (MIT).
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//******************************************************************************

#include "Starboard.h"
#include "StubReturn.h"
#include "UIKit/UIKit.h"
#include "UIKit/UIView.h"
#include "CoreGraphics/CGContext.h"
#include "Foundation/NSMutableString.h"
#include "Foundation/NSDictionary.h"
#include "Foundation/NSURL.h"
#include "Foundation/NSError.h"
#include "UIKit/UIScrollView.h"
#include "UIKit/UIApplication.h"
#include "UIKit/UIColor.h"
#include "UIViewInternal.h"

#include "UIKit/UIWebView.h"
#include "UWP/WindowsUIXamlControls.h"

#include <algorithm>

@implementation UIWebView {
    id _delegate;
    idretaintype(NSURLRequest) _request;
    bool _isLoading;
    StrongId<UIScrollView> _scrollView;
    StrongId<WXCWebView> _xamlWebControl;
    EventRegistrationToken _xamlLoadCompletedEventCookie;
    EventRegistrationToken _xamlLoadStartedEventCookie;
    EventRegistrationToken _xamlUnsupportedUriSchemeEventCookie;
}

/**
 @Status Stub
*/
- (void)setScalesPageToFit:(BOOL)scaleToFit {
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
- (void)setDelegate:(id)delegate {
    _delegate = delegate;
}

/**
 @Status Interoperable
*/
- (id)delegate {
    return _delegate;
}

/**
 @Status Interoperable
*/
- (BOOL)isLoading {
    return _isLoading;
}

/**
 @Status Caveat
 @Notes Only URL property in request is used
*/
- (void)loadRequest:(NSURLRequest*)request {
    _request = request;
    NSURL* url = [request URL];
    NSString* urlStr = [url absoluteString];

    StrongId<WWHHttpMethod*> method;
    StrongId<WWHHttpRequestMessage*> msg;
    StrongId<WFUri*> uri;

    method.attach([WWHHttpMethod make:request.HTTPMethod]);
    uri.attach([WFUri makeUri:urlStr]);
    msg.attach([WWHHttpRequestMessage make:method uri:uri]);

    [request.allHTTPHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString* field, NSString* value, BOOL* stop) {
        [[msg headers] append:field value:value];
    }];

    _isLoading = true;

    RunSynchronouslyOnMainThread(^{
        [_xamlWebControl navigateWithHttpRequestMessage:msg];
    });
}

static void _initUIWebView(UIWebView* self) {
    // Store a strongly-typed backing scrollviewer
    self->_xamlWebControl = rt_dynamic_cast<WXCWebView>([self xamlElement]);
    if (!self->_xamlWebControl) {
        FAIL_FAST();
    }

    __block UIWebView* weakSelf = self;
    self->_xamlLoadCompletedEventCookie = [self->_xamlWebControl addLoadCompletedEvent:^void(RTObject* sender, WUXNNavigationEventArgs* e) {
        weakSelf->_isLoading = false;

        if ([weakSelf->_delegate respondsToSelector:@selector(webViewDidFinishLoad:)]) {
            [weakSelf->_delegate webViewDidFinishLoad:weakSelf];
        }
    }];

    self->_xamlLoadStartedEventCookie =
        [self->_xamlWebControl addNavigationStartingEvent:^void(RTObject* sender, WXCWebViewNavigationStartingEventArgs* e) {
            // Give the client a chance to cancel the navigation
            if ([weakSelf->_delegate respondsToSelector:@selector(webView:shouldStartLoadWithRequest:navigationType:)]) {
                NSURL* url = [NSURL URLWithString:e.uri.absoluteUri];
                NSURLRequest* request = [NSURLRequest requestWithURL:url];

                // ???? XAML doesn't expose this information to us
                UIWebViewNavigationType navigationType = UIWebViewNavigationTypeOther;

                if (![weakSelf->_delegate webView:weakSelf shouldStartLoadWithRequest:request navigationType:navigationType]) {
                    e.cancel = YES;
                    return;
                }
            }

            // Cancellation declined, navigation is proceeding
            if ([weakSelf->_delegate respondsToSelector:@selector(webViewDidStartLoad:)]) {
                [weakSelf->_delegate webViewDidStartLoad:weakSelf];
            }
        }];

    self->_xamlUnsupportedUriSchemeEventCookie = [self->_xamlWebControl
        addUnsupportedUriSchemeIdentifiedEvent:^(RTObject* sender, WXCWebViewUnsupportedUriSchemeIdentifiedEventArgs* e) {
            if ([weakSelf->_delegate respondsToSelector:@selector(webView:shouldStartLoadWithRequest:navigationType:)]) {
                NSURL* url = [NSURL URLWithString:e.uri.absoluteUri];
                NSURLRequest* request = [NSURLRequest requestWithURL:url];
                UIWebViewNavigationType navigationType = UIWebViewNavigationTypeOther;

                // The WebView doesn't know what to do with this URL, but give our client a crack at it
                if ([weakSelf->_delegate webView:weakSelf shouldStartLoadWithRequest:request navigationType:navigationType]) {
                    // Client said to proceed, so pass the URL off to the system URI resolver
                } else {
                    // Client took care of the URL
                    e.handled = YES;
                }
            }
        }];

    // Add handler which will be invoked when user calls window.external.notify(msg) function in javascript
    [self->_xamlWebControl addScriptNotifyEvent:^void(RTObject* sender, WXCNotifyEventArgs* e) {
        // Send event to webView delegate
        NSURL* url = [NSURL URLWithString:e.callingUri.absoluteUri];
        if ([weakSelf->_delegate respondsToSelector:@selector(webView:scriptNotify:value:)]) {
            [weakSelf->_delegate webView:weakSelf scriptNotify:url value:e.value];
        }
    }];

    CGRect bounds;
    bounds = [self bounds];

    //  For compatibility only
    self->_scrollView.attach([[UIScrollView alloc] initWithFrame:bounds]);

    [self setNeedsLayout];
}

/**
 @Status Interoperable
*/
- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        RunSynchronouslyOnMainThread(^{
            _initUIWebView(self);
        });
    }

    return self;
}

/**
 Microsoft Extension
*/
- (instancetype)initWithFrame:(CGRect)frame xamlElement:(WXFrameworkElement*)xamlElement {
    if (self = [super initWithFrame:frame xamlElement:xamlElement]) {
        RunSynchronouslyOnMainThread(^{
            _initUIWebView(self);
        });
    }

    return self;
}

/**
 Microsoft Extension
*/
+ (WXFrameworkElement*)createXamlElement {
    return [[WXCWebView make] autorelease];
}

/**
 @Status Caveat
 @Notes May not be fully implemented
*/
- (instancetype)initWithCoder:(NSCoder*)coder {
    [super initWithCoder:coder];

    _initUIWebView(self);

    return self;
}

/**
 @Status Caveat
 @Notes baseURL parameter not supported
*/
- (void)loadHTMLString:(NSString*)string baseURL:(NSURL*)baseURL {
    _isLoading = true;

    NSString* urlStr = [baseURL absoluteString];
    [_xamlWebControl navigateToString:string];

    [self sizeToFit];
}

/**
 @Status Stub
*/
- (void)loadData:(NSData*)data MIMEType:(NSString*)mimeType textEncodingName:(NSString*)encoding baseURL:(NSURL*)baseURL {
    UNIMPLEMENTED();
    _isLoading = true;

    assert(0 && "loadData:mimeTime:textEncodingName: not implemented");
}

/**
 @Status Interoperable
*/
- (void)stopLoading {
    _isLoading = false;
    [_xamlWebControl stop];
}

- (void)setDetectsPhoneNumbers:(BOOL)detect {
}

/**
 @Status Stub
*/
- (NSString*)stringByEvaluatingJavaScriptFromString:(NSString*)string {
    UNIMPLEMENTED_WITH_MSG(
        "stringByEvaluatingJavaScriptFromString is not supported on our platform. Call evaluateJavaScript:completionHandler: instead.");
    return StubReturn();
}

/**
 @Status Caveat
  @Notes This is a workaround. Original UIWebView does not have this method
*/
- (void)evaluateJavaScript:(NSString*)javaScriptString completionHandler:(void (^)(id, NSError*))completionHandler {
    [_xamlWebControl invokeScriptAsync:@"eval"
        arguments:[NSArray arrayWithObject:javaScriptString]
        success:^void(NSString* success) {
            if (completionHandler != nil) {
                completionHandler(success, nil);
            }
        }
        failure:^void(NSError* failure) {
            if (completionHandler != nil) {
                completionHandler(nil, failure);
            }
        }];
}

/**
 @Status Stub
*/
- (void)setDataDetectorTypes:(UIDataDetectorTypes)types {
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
- (BOOL)canGoBack {
    return _xamlWebControl.get().canGoBack;
}

/**
 @Status Interoperable
*/
- (BOOL)canGoForward {
    return _xamlWebControl.get().canGoForward;
}

/**
 @Status Interoperable
*/
- (void)reload {
    [_xamlWebControl refresh];
}

/**
 @Status Interoperable
*/
- (void)goBack {
    [_xamlWebControl goBack];
}

/**
 @Status Interoperable
*/
- (void)goForward {
    [_xamlWebControl goForward];
}

/**
 @Status Interoperable
*/
- (NSURLRequest*)request {
    return _request;
}

/**
 @Status Interoperable
*/
- (void)setBackgroundColor:(UIColor*)color {
    CGFloat r = 0;
    CGFloat g = 0;
    CGFloat b = 0;
    CGFloat a = 0;

    [super setBackgroundColor:color];

    [color getRed:&r green:&g blue:&b alpha:&a];

    // XAML WebView transparency is not used unless it's set to the transparent system color.
    if (a != 1.0f) {
        [_xamlWebControl setDefaultBackgroundColor:[WUColors transparent]];
    } else {
        [_xamlWebControl setDefaultBackgroundColor:[WUColorHelper fromArgb:255
                                                                         r:(unsigned char)(r * 255.0)
                                                                         g:(unsigned char)(g * 255.0)
                                                                         b:(unsigned char)(b * 255.0)]];
    }
}

/**
 @Status Interoperable
*/
- (void)dealloc {
    RunSynchronouslyOnMainThread(^{
        [_xamlWebControl removeLoadCompletedEvent:_xamlLoadCompletedEventCookie];
        [_xamlWebControl removeNavigationStartingEvent:_xamlLoadStartedEventCookie];
        [_xamlWebControl removeUnsupportedUriSchemeIdentifiedEvent:_xamlUnsupportedUriSchemeEventCookie];
        _xamlWebControl = nil;
    });

    [super dealloc];
}

/**
 @Status Stub
*/
- (UIScrollView*)scrollView {
    UNIMPLEMENTED();
    return _scrollView;
}

/**
 @Status Stub
*/
- (void)setScrollsToTop:(BOOL)scrollsToTop {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (void)setAllowsInlineMediaPlayback:(BOOL)allow {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (void)setMediaPlaybackRequiresUserAction:(BOOL)allow {
    UNIMPLEMENTED();
}
@end
