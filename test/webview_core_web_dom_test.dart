@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_core/webview_core.dart';

@JS('window')
external _TestJSWindow get _hostWindow;

extension type const _TestJSWindow(JSObject _raw) implements JSObject {
  external void postMessage(JSAny? message, String targetOrigin);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'WebWebViewBridge mounts iframe, blocks spoofed postMessage from host window, and cleans up on dispose',
    (WidgetTester tester) async {
      final receivedMessages = <String>[];
      final controller = WebViewController();
      await controller.setBackgroundColor(const Color(0xFF0F172A));
      await controller.addJavaScriptChannel(
        'SecureBridge',
        onMessageReceived: (JavaScriptMessage msg) {
          receivedMessages.add(msg.message);
        },
      );
      await controller.loadHtmlString(
        '<!DOCTYPE html><title>Web DOM Test</title><p>Hello Wasm</p>',
        baseUrl: 'https://keyscope.dev/',
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 320,
            height: 200,
            child: WebViewWidget(controller: controller),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(HtmlElementView), findsOneWidget);
      expect(await controller.currentUrl(), 'https://keyscope.dev/');

      // Attempt a spoofed postMessage originating from the outer host window
      // rather than the iframe's own contentWindow -> MUST be rejected!
      final spoofPayload = <String, Object?>{
        '__webview_core_id': controller.controllerId,
        '__webview_core_channel': 'SecureBridge',
        'message': 'forged-from-outside-iframe',
      }.jsify();
      _hostWindow.postMessage(spoofPayload, '*');
      await tester.pump(const Duration(milliseconds: 50));
      expect(receivedMessages, isEmpty);

      // Toggle JavaScript mode (`sandbox` attribute) and background color.
      await controller.setJavaScriptMode(JavaScriptMode.disabled);
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(const Color(0xFFF8FAFC));

      // Exercise cookie manager on Web (`clearCookies` returns false safely).
      final cookieManager = WebViewCookieManager();
      expect(await cookieManager.clearCookies(), isFalse);
      await cookieManager.setCookie(
        const WebViewCookie(name: 'wv_test', value: '1', domain: 'localhost'),
      );

      await controller.dispose();
      expect(controller.isDisposed, isTrue);
    },
  );
}
