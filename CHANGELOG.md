## 1.1.0

Runtime stability release. Fixes native views that stopped responding after being hidden and shown again, restores in-page clicks on freshly mounted previews, adds the missing right-click menu on Windows, and ships a real-native integration test suite.

### Fixed
* **macOS: native `WKWebView` was permanently destroyed when Flutter hid it.** The v1.0.0 teardown that reacted to `viewDidMoveToSuperview` also fired when the Flutter engine temporarily detached the platform view (`IndexedStack`, `Offstage`, collapsing panels, frames without a platform-view layer). The page was stopped, its delegate and script handlers were removed, and every later call (`loadHtmlString`, `evaluateJavaScript`, `reload`, …) silently returned `null`, leaving an unresponsive view that only recovered after the user chose *Reload*. The bridge is now owned by the view (`view → bridge`, `bridge ⇢ view` weak) and is released only when Flutter releases the view or `WebViewController.dispose()` is called.
* **macOS: `evaluateJavaScript('1+1')` returned `'2.0'`** instead of `'2'`; integral JavaScript numbers are now delivered as integers on every platform.
* **Windows: no context menu.** Composition hosting never renders the default WebView2 menu. Right-click now shows the Edge menu (Back, Forward, Reload, Copy, …) as a native popup through `ContextMenuRequested`.
* **Windows: keyboard focus trap.** The WebView host consumed every key. `Tab`, `F1`–`F12`, `Escape`, modifier-only presses, and `Win` combinations now stay with Flutter so focus traversal and application shortcuts keep working.
* **All desktop and iOS: `target="_blank"` links and `window.open()` were silently dropped** (macOS, iOS, Linux) or handled by an external popup (Windows). `http(s)` targets now open in place.

### Added
* **macOS / iOS: automatic recovery from a crashed `WebContent` process.** The failure is reported through `NavigationDelegate.onWebResourceError` (`WebResourceErrorType.webContentProcessTerminated`) and the page is reloaded.
* **Native integration tests** (`example/integration_test/`): hide / show cycles, remounts, rounded-clip resize storms, debounced typing storms, JavaScript channels, navigation prevention, cookies, `target="_blank"`, and the example application itself, executed against the real platform plugin (`flutter test integration_test -d macos`).
* **Windows host key-policy unit test.**
* **Redesigned example application** with an HTTP response preview, a Mail composer live preview that proves editor text is never modified by preview theming, and a Diagnostics tab (UI heartbeat, native round-trip probe, stress actions, event log).

## 1.0.0

Initial stable release of **`webview_core`** — a unified, zero-dependency native WebView plugin for Flutter across **Android**, **iOS**, **Linux**, **macOS**, **Windows**, and **Web / WebAssembly** (`dart2wasm`).

### Zero-Dependency 6-Platform Architecture
* Eliminates all external hosted Pub, CocoaPods/SwiftPM, Gradle/Maven, and NuGet CLI dependencies (`dependencies:` contains **only** Flutter SDK packages: `flutter` and `flutter_web_plugins`), replacing fragmented federated WebView packages with a single self-contained plugin built on `package:flutter/widgets.dart`.
* **Android (`Kotlin` / `android.webkit.WebView`, minSdk 24, compileSdk 36, AGP 8.x & 9.x Built-in Kotlin compatible)**: Zero-`androidx` `PlatformViewFactory` implementation using UTF-8 `loadDataWithBaseURL`, synchronous-halt + async-decision `NavigationDecision.prevent` enforcement, custom-header and non-GET `loadRequest` support, CSS logical-pixel scroll synchronization, `CookieManager` integration, `@JavascriptInterface` channels, and zero deprecated APIs.
* **iOS (`Swift` / `WKWebView`, iOS 14.0+)**: Dual Swift Package Manager (`Package.swift`) and CocoaPods (`webview_core.podspec`) layout with `PrivacyInfo.xcprivacy`, `WKWebpagePreferences.allowsContentJavaScript`, `isOpaque = false` backdrop synchronization, weak instance registry for automatic `UiKitView` unmount cleanup, `WKHTTPCookieStore` support, and zero deprecated APIs.
* **Linux (`C++14` / `GTK3` & `webkit2gtk-4.1`)**: Compiles cleanly under Flutter's standard `cxx_std_14` CMake settings and Ubuntu 22.04 (`GLib 2.72.4`) headers, combining `GtkLayout` viewport clipping inside `GtkOverlay` with automatic `Visibility` / `RenderIndexedStack` / `Offstage` / modal-route and `hitTestInView` occlusion tracking, `destroy`-signal lifecycle guards, zoom-lock scripts, and `WebKitCookieManager` support.
* **macOS (`Swift` / `WKWebView`, macOS 11.0+)**: Dual Swift Package Manager (`Package.swift`) and CocoaPods (`webview_core.podspec`) layout with `PrivacyInfo.xcprivacy`, full `setBackgroundColor` support via direct `InteractiveWKWebView` `AppKitView` hit-testing and `drawsBackground = false` + `CALayer` / `underPageBackgroundColor` backdrop, automatic superview detach cleanup, and zero deprecated APIs.
* **Windows (`C++17` / `WRL` & `WebView2LoaderStatic.lib` `x64`/`ARM64`, `/W4 /WX` & `_HAS_EXCEPTIONS=0` clean)**: Downloads and verifies the official `Microsoft.Web.WebView2` archive directly in CMake without `nuget.exe` or `WIL`, compositing `ICoreWebView2CompositionController` frames via zero-copy DXGI shared GPU textures (`FlutterDesktopGpuSurfaceDescriptor`, with automatic `PixelBufferTexture` fallback on software adapters), supporting `> 2 MB` HTML documents via in-memory `WebResourceRequested` streams, and forwarding HiDPI bounds, keyboard shortcuts, and pointer modifiers.
* **Web & WebAssembly (`dart:js_interop` / `dart:ui_web`, `dart2wasm` clean)**: Conditional-import architecture isolating `dart:io` from Web, featuring pure SDK `dart:js_interop` `HTMLIFrameElement` rendering (`srcdoc`, `src`, `sandbox`, Standards-Mode `<!DOCTYPE>` preservation, CSS `rgba()` background, and `contentWindow`-verified `postMessage` channels).

### Compatibility Barrels & Core Types
* `package:webview_core/webview_core.dart`: Primary API exporting `WebViewController`, `WebViewWidget`, `WebView`, `WebViewCookieManager`, `WebViewCookie`, `JavaScriptMode`, `LoadRequestMethod`, `NavigationDelegate`, `NavigationDecision`, `NavigationRequest`, `WebResourceError`, `WebResourceErrorType`, `UrlChange`, and `JavaScriptMessage`.
* `package:webview_core/webview_flutter.dart`: Compatibility barrel for core `webview_flutter` APIs.
* `package:webview_core/webview_all.dart`: Compatibility barrel for `webview_all` APIs.
