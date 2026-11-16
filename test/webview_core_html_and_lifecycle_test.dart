import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_core/src/html_decorator.dart';
import 'package:webview_core/src/platform_bridge.dart';
import 'package:webview_core/webview_core.dart';

final class _FakePlatformBridge extends WebViewPlatformBridge {
  final Map<int, WebViewPlatformCallbacks> callbacks =
      <int, WebViewPlatformCallbacks>{};
  final List<WebViewCreationParams> mountedParams = <WebViewCreationParams>[];
  final List<String> log = <String>[];

  @override
  void registerController(int controllerId, WebViewPlatformCallbacks cb) {
    callbacks[controllerId] = cb;
  }

  @override
  void unregisterController(int controllerId) {
    callbacks.remove(controllerId);
  }

  @override
  Widget buildView({
    required BuildContext context,
    required WebViewCreationParams params,
    Key? key,
  }) {
    mountedParams.add(params);
    scheduleMicrotask(() {
      callbacks[params.controllerId]?.handleViewCreated(params.controllerId);
    });
    return ColoredBox(
      key: key,
      color: params.backgroundColor,
      child: const SizedBox.expand(),
    );
  }

  @override
  Future<void> loadHtmlString(
    int controllerId,
    String html, {
    String? baseUrl,
  }) async {
    log.add('loadHtmlString:$html@${baseUrl ?? ''}');
  }

  @override
  Future<void> loadRequest(
    int controllerId, {
    required String url,
    required String method,
    required Map<String, String> headers,
    Uint8List? body,
  }) async {
    log.add('loadRequest:$method:$url');
  }

  @override
  Future<void> loadFile(int controllerId, String path) async {
    log.add('loadFile:$path');
  }

  @override
  Future<void> loadFlutterAsset(int controllerId, String assetKey) async {
    log.add('loadFlutterAsset:$assetKey');
  }

  @override
  Future<void> setJavaScriptEnabled(int controllerId, bool enabled) async {
    log.add('setJs:$enabled');
  }

  @override
  Future<void> setBackgroundColor(int controllerId, Color color) async {
    log.add('setBg:${color.toARGB32()}');
  }

  @override
  Future<void> setUserAgent(int controllerId, String? userAgent) async {
    log.add('setUa:${userAgent ?? ''}');
  }

  @override
  Future<void> enableZoom(int controllerId, bool enabled) async {
    log.add('zoom:$enabled');
  }

  @override
  Future<void> setHasNavigationDecision(int controllerId, bool enabled) async {
    log.add('navDecision:$enabled');
  }

  @override
  Future<void> runJavaScript(int controllerId, String script) async {
    log.add('runJs:$script');
  }

  @override
  Future<Object?> runJavaScriptReturningResult(
    int controllerId,
    String script,
  ) async => 'ok';

  @override
  Future<void> addJavaScriptChannel(int controllerId, String name) async {
    log.add('addChannel:$name');
  }

  @override
  Future<void> removeJavaScriptChannel(int controllerId, String name) async {
    log.add('removeChannel:$name');
  }

  @override
  Future<void> reload(int controllerId) async {
    log.add('reload');
  }

  @override
  Future<void> stopLoading(int controllerId) async {
    log.add('stop');
  }

  @override
  Future<bool> canGoBack(int controllerId) async => false;

  @override
  Future<bool> canGoForward(int controllerId) async => false;

  @override
  Future<void> goBack(int controllerId) async {}

  @override
  Future<void> goForward(int controllerId) async {}

  @override
  Future<String?> currentUrl(int controllerId) async => null;

  @override
  Future<String?> getTitle(int controllerId) async => 'FakeTitle';

  @override
  Future<void> scrollTo(int controllerId, int x, int y) async {}

  @override
  Future<void> scrollBy(int controllerId, int x, int y) async {}

  @override
  Future<Offset> getScrollPosition(int controllerId) async => Offset.zero;

  @override
  Future<void> clearCache(int controllerId) async {}

  @override
  Future<void> clearLocalStorage(int controllerId) async {}

  @override
  Future<bool> clearCookies() async => true;

  @override
  Future<void> setCookie(WebViewCookie cookie) async {
    log.add('setCookie:${cookie.name}=${cookie.value}');
  }

  @override
  Future<void> dispose(int controllerId) async {
    log.add('dispose:$controllerId');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    WebViewPlatformBridge.debugOverrideInstance = null;
  });

  group('decorateHtmlDocument Standards Mode and channel injection', () {
    test(
      'never prepends markup before <!DOCTYPE html> when <head> is absent',
      () {
        const raw = '<!DOCTYPE html><div>Standards Mode</div>';
        final out = decorateHtmlDocument(
          controllerId: 3,
          html: raw,
          channels: const <String>['Bridge'],
          baseUrl: 'https://keyscope.dev/app?a=1&b="2"',
        );
        expect(out.startsWith('<!DOCTYPE html><head><base href='), isTrue);
        expect(
          out,
          contains('href="https://keyscope.dev/app?a=1&amp;b=&quot;2&quot;"'),
        );
        expect(out, contains('__webview_core_id:3'));
        expect(out, contains('__webview_core_channel:"Bridge"'));
        expect(out.endsWith('<div>Standards Mode</div>'), isTrue);
      },
    );

    test('injects inside existing <head> when present', () {
      const raw =
          '<!DOCTYPE html><html><head><meta charset="utf-8"></head><body>Hi</body></html>';
      final out = decorateHtmlDocument(
        controllerId: 1,
        html: raw,
        channels: const <String>{},
        baseUrl: 'https://example.com/',
      );
      expect(
        out,
        '<!DOCTYPE html><html><head><base href="https://example.com/"><meta charset="utf-8"></head><body>Hi</body></html>',
      );
    });

    test(
      'injects <head> wrapper right after <html> when <head> is omitted',
      () {
        const raw = '<html lang="en"><body>Content</body></html>';
        final out = decorateHtmlDocument(
          controllerId: 9,
          html: raw,
          channels: const <String>['Ch"Quote'],
        );
        expect(out.startsWith('<html lang="en"><head><script>'), isTrue);
        expect(out, contains(r'window["Ch\"Quote"]'));
      },
    );
  });

  testWidgets(
    'remounting WebViewWidget with an existing WebViewController retains loaded content',
    (WidgetTester tester) async {
      final fakeBridge = _FakePlatformBridge();
      WebViewPlatformBridge.debugOverrideInstance = fakeBridge;

      final controller = WebViewController();
      await controller.loadHtmlString(
        '<h1>Persistent Preview</h1>',
        baseUrl: 'https://keyscope.dev',
      );

      final mounted = ValueNotifier<bool>(true);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ValueListenableBuilder<bool>(
            valueListenable: mounted,
            builder: (BuildContext context, bool show, Widget? _) {
              if (!show) {
                return const SizedBox.shrink();
              }
              return SizedBox(
                width: 300,
                height: 200,
                child: WebViewWidget(controller: controller),
              );
            },
          ),
        ),
      );
      await tester.pump();

      expect(fakeBridge.mountedParams, hasLength(1));
      expect(
        fakeBridge.mountedParams.first.initialHtml,
        '<h1>Persistent Preview</h1>',
      );
      expect(
        fakeBridge.mountedParams.first.initialBaseUrl,
        'https://keyscope.dev',
      );

      // Unmount WebViewWidget while keeping WebViewController alive.
      mounted.value = false;
      await tester.pump();

      // Remount WebViewWidget with the same controller -> must NOT be blank!
      fakeBridge.mountedParams.clear();
      mounted.value = true;
      await tester.pump();

      expect(fakeBridge.mountedParams, hasLength(1));
      expect(
        fakeBridge.mountedParams.single.initialHtml,
        '<h1>Persistent Preview</h1>',
      );
      expect(
        fakeBridge.mountedParams.single.initialBaseUrl,
        'https://keyscope.dev',
      );

      // Also verify pre-mount/remount loadFile queues cleanly on remount.
      mounted.value = false;
      await tester.pump();
      fakeBridge.log.clear();

      await controller.loadFile('/tmp/local_report.html');
      mounted.value = true;
      await tester.pump();
      await tester.pump();
      expect(fakeBridge.log, contains('loadFile:/tmp/local_report.html'));

      mounted.dispose();
      await controller.dispose();
      expect(controller.isDisposed, isTrue);
    },
  );
}
