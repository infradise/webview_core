# webview_core

[![Pub Version](https://img.shields.io/pub/v/webview_core)](https://pub.dev/packages/webview_core)
[![Dependencies](https://img.shields.io/badge/dependencies-zero-brightgreen)](https://pub.dev/packages/webview_core)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](https://github.com/infradise/webview_core/blob/main/LICENSE)

Zero-dependency native WebView plugin for Flutter across **Android**, **iOS**, **Linux**, **macOS**, **Windows**, and **Web / WebAssembly**.

`webview_core` unifies and replaces [`webview_flutter`](https://pub.dev/packages/webview_flutter) and [`webview_all`](https://pub.dev/packages/webview_all) in a single self-contained plugin with **zero external hosted dependencies**.

| Platform | Support | Implementation |
| :--- | :--- | :--- |
| Android | API 24+ | [WebView](https://developer.android.com/reference/android/webkit/WebView) |
| iOS | 14.0+ | [WKWebView](https://developer.apple.com/documentation/webkit/wkwebview) |
| macOS | 11.0+ | [WKWebView](https://developer.apple.com/documentation/webkit/wkwebview) |
| Windows | Win10 21H1+ / Win11 | [WebView2](https://learn.microsoft.com/en-us/microsoft-edge/webview2/) |
| Linux | webkit2gtk-4.1 | [WebKitGTK](https://webkitgtk.org/) |
| Web | JS & Wasm | [dart:js_interop](https://api.dart.dev/dart-js_interop/) |

## Why `webview_core` Exists

Integrating WebView rendering across mobile, desktop, and WebAssembly in Flutter typically pulls in fragmented federated packages and platform workarounds:

- `webview_flutter` does not support **Linux** or **Windows** desktop targets and pulls in multiple federated platform packages.
- `webview_all` pulls in **8 federated packages** (`webview_all_*` and `webview_platform_interface`), fails to compile against Flutter's default `cxx_std_14` Linux CMake template on Ubuntu 22.04 (`GLib 2.72.4`), downloads 32-bit `nuget.exe` and external `WIL` packages during Windows builds, schedules idle frame callbacks on Linux, and throws `UnimplementedError` on `setBackgroundColor` on macOS.

`webview_core` eliminates **every** external Pub, CocoaPods/SwiftPM, Gradle/Maven, and NuGet CLI dependency (`dependencies` contains **only** Flutter SDK packages: `flutter` and `flutter_web_plugins`):

- **Android (`Kotlin` + `android.webkit.WebView`, minSdk 24, compileSdk 36)**: AGP 8.x and AGP 9.x Built-in Kotlin compatible with zero `androidx` dependencies, UTF-8 `loadDataWithBaseURL` rendering, main-frame `NavigationDecision.prevent` enforcement, non-GET `loadRequest` support, CSS logical-pixel scroll synchronization, and `@JavascriptInterface` channels.
- **iOS (`Swift` + `WKWebView`, iOS 14.0+)**: Dual Swift Package Manager (`Package.swift`) and CocoaPods (`webview_core.podspec`) layout with `PrivacyInfo.xcprivacy`, `WKWebpagePreferences.allowsContentJavaScript`, `isOpaque = false` background synchronization, automatic unmount teardown without retain cycles, and zero deprecated APIs. `target="_blank"` links open in place and a crashed `WebContent` process is reloaded automatically.
- **Linux (`C++14` + `GTK3` + `webkit2gtk-4.1`)**: Compiles cleanly under Flutter's default `cxx_std_14` and Ubuntu 22.04 (`GLib 2.72.4`) headers, mounting a clipped viewport container (`GDK_WINDOW_SUBSURFACE` on Wayland, `GDK_WINDOW_CHILD` on X11) inside `FlView`'s `GtkOverlay` without unrealizing `FlView`, setting `WEBKIT_DISABLE_DMABUF_RENDERER=1` by default for NVIDIA Wayland stability, restoring GTK focus to `FlView` on surface click or hide/dispose, tracking `Visibility` / `IndexedStack` / `Offstage` / popup occlusion and `RepaintBoundary` shifts with zero idle polling, preserving inline `loadHtmlString` documents on `reload()`, and opening `target="_blank"` / `window.open()` links in place.
- **macOS (`Swift` + `WKWebView`, macOS 11.0+)**: Dual Swift Package Manager (`Package.swift`) and CocoaPods (`webview_core.podspec`) layout with `PrivacyInfo.xcprivacy`, direct `WKWebView` `AppKitView` hit-testing and scrolling, full `setBackgroundColor` support (`drawsBackground = false` + `CALayer` / `underPageBackgroundColor` backdrop), trackpad gesture-phase protection preventing `FlutterViewController` crashes during native context menus or view-boundary gestures, and zero deprecated APIs. The native view survives any number of hide / show cycles (`IndexedStack`, `Offstage`, collapsing panels) and is released only when Flutter releases it or `WebViewController.dispose()` is called. A crashed `WebContent` process is reported through `onWebResourceError` (`webContentProcessTerminated`) and reloaded automatically; `target="_blank"` links open in place.
- **Windows (`C++17` + `WRL` + `WebView2LoaderStatic.lib` `x64`/`ARM64`)**: Compiles cleanly under `/W4 /WX` and `_HAS_EXCEPTIONS=0` without `nuget.exe` or `WIL`, compositing `ICoreWebView2CompositionController` frames via zero-copy DXGI shared GPU textures (`FlutterDesktopGpuSurfaceDescriptor`, with automatic `PixelBufferTexture` fallback on software WARP adapters) and supporting `> 2 MB` inline HTML documents via in-memory stream responses. Right-click opens the standard Edge context menu (Back, Forward, Reload, Copy, …) rendered as a native popup, `target="_blank"` links open in place, and Tab / function keys / `Win` combinations are never swallowed by the WebView.
- **Web / WebAssembly (`dart:js_interop` + `dart:ui_web`, `dart2wasm`-ready)**: Pure SDK `dart:js_interop` `HTMLIFrameElement` implementation (`srcdoc`, `src`, `sandbox`, CSS `rgba()` background, and source-verified `postMessage` channels) with zero `package:web` or `dart:html` imports.

## Compatibility Chart

| API | Android | iOS | Linux | macOS | Windows | Web (Wasm) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| `WebViewWidget` / `WebView` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `loadHtmlString()` (`baseUrl`) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `loadRequest()` / `loadUrl()` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (`GET`) |
| `loadFlutterAsset()` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `loadFile()` | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ URL fallback |
| `setJavaScriptMode()` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (`sandbox`) |
| `setBackgroundColor()` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `runJavaScript()` / `evaluateJavaScript()` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (same-origin) |
| `addJavaScriptChannel()` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (`srcdoc`) |
| `NavigationDelegate` | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ `loadRequest` & load events |
| `IndexedStack` / `Offstage` / modal instant hide | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Right-click context menu | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (browser) |
| `target="_blank"` / `window.open()` opens in place | ✅ (platform default) | ✅ | ✅ | ✅ | ✅ | ✅ (iframe) |
| `WebViewCookieManager` | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ `document.cookie` |
| `setUserAgent()` / `enableZoom()` | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| `clearCache()` | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| `clearLocalStorage()` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (same-origin) |

## System Requirements

- **Linux**: Requires `libwebkit2gtk-4.1-dev` at build time (`sudo apt-get install libwebkit2gtk-4.1-dev` on Ubuntu 22.04+ / Debian 12+).
- **Windows**: Uses the evergreen Microsoft Edge WebView2 Runtime on Windows 10 21H1+ and Windows 11 (borderless `IGraphicsCaptureSession3` capture; Windows 10 2004 renders functionally with OS capture border) and links `WebView2LoaderStatic.lib` (`x64` / `arm64`) automatically via CMake.
- **macOS**: Add `<key>com.apple.security.network.client</key><true/>` to `macos/Runner/*.entitlements` when loading remote `https://` URLs under App Sandbox.
- **Android**: Add `<uses-permission android:name="android.permission.INTERNET"/>` to `AndroidManifest.xml` when loading remote URLs.

## Installation

```yaml
dependencies:
  webview_core: ^1.1.0
```

## Import Barrels

| Use Case | Import |
| :--- | :--- |
| **Primary API (Recommended)** | `import 'package:webview_core/webview_core.dart';` |
| **`webview_flutter` core migration** | `import 'package:webview_core/webview_flutter.dart';` |
| **`webview_all` migration** | `import 'package:webview_core/webview_all.dart';` |

## Usage Examples

### 1. HTML Preview with Dark / Light Background Synchronization

```dart
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:webview_core/webview_core.dart';

class HtmlPreviewPane extends StatefulWidget {
  const HtmlPreviewPane({
    required this.html,
    required this.backgroundColor,
    this.baseUrl,
    super.key,
  });

  final String html;
  final Color backgroundColor;
  final String? baseUrl;

  @override
  State<HtmlPreviewPane> createState() => _HtmlPreviewPaneState();
}

class _HtmlPreviewPaneState extends State<HtmlPreviewPane> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    unawaited(_controller.setJavaScriptMode(JavaScriptMode.unrestricted));
    unawaited(_controller.setBackgroundColor(widget.backgroundColor));
    unawaited(_controller.loadHtmlString(widget.html, baseUrl: widget.baseUrl));
  }

  @override
  void didUpdateWidget(covariant HtmlPreviewPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backgroundColor != widget.backgroundColor) {
      unawaited(_controller.setBackgroundColor(widget.backgroundColor));
    }
    if (oldWidget.html != widget.html || oldWidget.baseUrl != widget.baseUrl) {
      unawaited(
        _controller.loadHtmlString(widget.html, baseUrl: widget.baseUrl),
      );
    }
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(
      key: const ValueKey<String>('html_preview'),
      controller: _controller,
    );
  }
}
```

### 2. URL Navigation Policy and JavaScript Channels

```dart
final controller = WebViewController();
unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
unawaited(
  controller.addJavaScriptChannel(
    'AppBridge',
    onMessageReceived: (JavaScriptMessage message) {
      debugPrint('From JS: ${message.message}');
    },
  ),
);
unawaited(
  controller.setNavigationDelegate(
    NavigationDelegate(
      onNavigationRequest: (NavigationRequest request) {
        if (!request.url.startsWith('https://')) {
          return NavigationDecision.prevent;
        }
        return NavigationDecision.navigate;
      },
    ),
  ),
);
unawaited(controller.loadRequest(Uri.parse('https://example.com')));
```

## Testing

- `flutter test` runs the Dart unit and widget tests (mocked platform channel).
- `cd example && flutter test integration_test -d macos` runs the **native** integration tests against the real `WKWebView` plugin (hide / show, remount, rounded-clip resize storms, debounced typing, `target=_blank`, JavaScript channels, cookies, and the full example application). The same suite runs on `windows` and `linux` (`xvfb-run`) hosts.

## License

Apache License 2.0 — Copyright 2026 Infradise Inc. See [LICENSE](LICENSE).
