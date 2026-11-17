@TestOn('vm')
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_core/webview_all.dart' as webview_all_compat;
import 'package:webview_core/webview_core.dart';
import 'package:webview_core/webview_flutter.dart' as webview_flutter_compat;

class _RawRenderIndexedStack extends MultiChildRenderObjectWidget {
  const _RawRenderIndexedStack({required this.index, required super.children});

  final int index;

  @override
  RenderIndexedStack createRenderObject(BuildContext context) {
    return RenderIndexedStack(index: index, textDirection: TextDirection.ltr);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderIndexedStack renderObject,
  ) {
    renderObject.index = index;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.infradise.webview_core');
  final recordedCalls = <MethodCall>[];

  setUp(() {
    recordedCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          recordedCalls.add(call);
          switch (call.method) {
            case 'create':
              return 7;
            case 'runJavaScriptReturningResult':
              final map = call.arguments as Map<Object?, Object?>;
              if (map['script'] == 'navigator.userAgent') {
                return 'MockAgent/1.0';
              }
              return '42';
            case 'canGoBack':
              return true;
            case 'canGoForward':
              return false;
            case 'currentUrl':
              return 'https://keyscope.dev/docs';
            case 'getTitle':
              return 'Keyscope Docs';
            case 'getScrollPosition':
              return <String, Object?>{'x': 12.0, 'y': 48.0};
            case 'clearCookies':
              return true;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('captures pre-mount configuration into WebViewCreationParams', () async {
    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.disabled);
    await controller.setBackgroundColor(const Color(0xFF1E293B));
    await controller.setUserAgent('CustomUA/1.0');
    await controller.enableZoom(false);
    await controller.addJavaScriptChannel('Bridge', onMessageReceived: (_) {});
    await controller.loadHtmlString(
      '<h1>Hello</h1>',
      baseUrl: 'https://example.com',
    );

    expect(await controller.currentUrl(), 'https://example.com');

    final recognizers = <Factory<OneSequenceGestureRecognizer>>{
      const Factory<TapGestureRecognizer>(TapGestureRecognizer.new),
    };
    final params = controller.buildCreationParams(
      gestureRecognizers: recognizers,
    );
    expect(params.javaScriptEnabled, isFalse);
    expect(params.backgroundColor, const Color(0xFF1E293B));
    expect(params.userAgent, 'CustomUA/1.0');
    expect(params.zoomEnabled, isFalse);
    expect(params.channelNames, <String>['Bridge']);
    expect(params.gestureRecognizers, recognizers);
    expect(params.initialHtml, '<h1>Hello</h1>');
    expect(params.initialBaseUrl, 'https://example.com');

    await controller.dispose();
  });

  test(
    'compatibility barrels re-export core and cookie manager types',
    () async {
      final c1 = webview_flutter_compat.WebViewController();
      final c2 = webview_all_compat.WebViewController();
      final cm = webview_flutter_compat.WebViewCookieManager();
      expect(c1, isA<WebViewController>());
      expect(c2, isA<WebViewController>());
      expect(cm, isA<WebViewCookieManager>());

      expect(await cm.clearCookies(), isTrue);
      await cm.setCookie(
        const webview_flutter_compat.WebViewCookie(
          name: 'session',
          value: 'abc123',
          domain: 'keyscope.dev',
        ),
      );
      expect(
        recordedCalls.any((MethodCall c) => c.method == 'clearCookies'),
        isTrue,
      );
      expect(
        recordedCalls.any((MethodCall c) {
          if (c.method != 'setCookie') {
            return false;
          }
          final args = c.arguments as Map<Object?, Object?>;
          return args['name'] == 'session' &&
              args['value'] == 'abc123' &&
              args['domain'] == 'keyscope.dev';
        }),
        isTrue,
      );

      await c1.dispose();
      await c2.dispose();
    },
  );

  testWidgets(
    'Linux host hides automatically on plain IndexedStack switch without TickerMode',
    (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final controller = WebViewController();
      await controller.setBackgroundColor(const Color(0xFF0F172A));
      await controller.loadHtmlString('<p>Linux Unrigged IndexedStack</p>');

      final activeTab = ValueNotifier<int>(0);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ValueListenableBuilder<int>(
            valueListenable: activeTab,
            builder: (BuildContext context, int tab, Widget? _) {
              return IndexedStack(
                index: tab,
                children: <Widget>[
                  SizedBox(
                    width: 400,
                    height: 300,
                    child: WebViewWidget(controller: controller),
                  ),
                  const SizedBox(width: 400, height: 300),
                ],
              );
            },
          ),
        ),
      );
      await tester.pump();

      expect(
        recordedCalls.where((MethodCall c) => c.method == 'create'),
        hasLength(1),
      );
      expect(
        recordedCalls.any((MethodCall c) {
          if (c.method != 'setGeometry') {
            return false;
          }
          final args = c.arguments as Map<Object?, Object?>;
          return args['visible'] == true;
        }),
        isTrue,
      );

      recordedCalls.clear();
      activeTab.value = 1;
      await tester.pump();

      expect(
        recordedCalls.any((MethodCall c) {
          if (c.method != 'setGeometry') {
            return false;
          }
          final args = c.arguments as Map<Object?, Object?>;
          return args['visible'] == false;
        }),
        isTrue,
      );

      // Verify zero recursive idle frame callbacks when idle.
      recordedCalls.clear();
      await tester.pump(const Duration(milliseconds: 200));
      expect(recordedCalls, isEmpty);

      // Switch back to tab 0 and verify visibility restores automatically.
      activeTab.value = 0;
      await tester.pump();
      expect(
        recordedCalls.any((MethodCall c) {
          if (c.method != 'setGeometry') {
            return false;
          }
          final args = c.arguments as Map<Object?, Object?>;
          return args['visible'] == true;
        }),
        isTrue,
      );

      activeTab.dispose();
      await controller.dispose();
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'Custom RenderIndexedStack without Visibility wrapper hides Linux and Windows hosts',
    (WidgetTester tester) async {
      for (final platform in <TargetPlatform>[
        TargetPlatform.linux,
        TargetPlatform.windows,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        recordedCalls.clear();

        final controller = WebViewController();
        await controller.loadHtmlString('<p>LazyIndexedStack check</p>');
        final activeTab = ValueNotifier<int>(0);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: ValueListenableBuilder<int>(
              valueListenable: activeTab,
              builder: (BuildContext context, int tab, Widget? _) {
                return _RawRenderIndexedStack(
                  index: tab,
                  children: <Widget>[
                    SizedBox(
                      width: 300,
                      height: 200,
                      child: WebViewWidget(controller: controller),
                    ),
                    const SizedBox(width: 300, height: 200),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pump();

        recordedCalls.clear();
        activeTab.value = 1;
        await tester.pump();

        final methodName = platform == TargetPlatform.linux
            ? 'setGeometry'
            : 'setVisibility';
        expect(
          recordedCalls.any((MethodCall c) {
            if (c.method != methodName) {
              return false;
            }
            final args = c.arguments as Map<Object?, Object?>;
            return args['visible'] == false;
          }),
          isTrue,
          reason: 'Expected $methodName(visible: false) on $platform',
        );

        activeTab.dispose();
        await controller.dispose();
      }
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'Linux host hides when covered by modal route or opaque Stack barrier and clips without squashing',
    (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final controller = WebViewController();
      await controller.loadHtmlString('<p>Modal & Clip Test</p>');

      final showBarrier = ValueNotifier<bool>(false);
      late BuildContext pageContext;

      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
            return PageRouteBuilder<T>(
              settings: settings,
              pageBuilder: (BuildContext ctx, _, _) => builder(ctx),
            );
          },
          home: Builder(
            builder: (BuildContext ctx) {
              pageContext = ctx;
              return ValueListenableBuilder<bool>(
                valueListenable: showBarrier,
                builder: (BuildContext context, bool covered, Widget? _) {
                  return Stack(
                    children: <Widget>[
                      Positioned(
                        left: 20,
                        top: 40,
                        width: 400,
                        height: 200,
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topLeft,
                            minWidth: 400,
                            maxWidth: 400,
                            minHeight: 300,
                            maxHeight: 300,
                            child: Transform.translate(
                              offset: const Offset(0, -60),
                              child: SizedBox(
                                width: 400,
                                height: 300,
                                child: WebViewWidget(controller: controller),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (covered)
                        const Positioned.fill(
                          child: AbsorbPointer(
                            child: ColoredBox(color: Color(0xAA000000)),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      );
      await tester.pump();

      final geomCalls = recordedCalls
          .where((MethodCall c) => c.method == 'setGeometry')
          .toList();
      expect(geomCalls, isNotEmpty);
      final visibleArgs = geomCalls.last.arguments as Map<Object?, Object?>;
      expect(visibleArgs['visible'], isTrue);
      // Clipped viewport height is 200, while full layout height remains 300!
      expect(visibleArgs['height'], 200);
      expect(visibleArgs['fullHeight'], 300);
      expect(visibleArgs['y'], 40);
      expect(visibleArgs['fullY'], -20);

      // Cover with non-route Stack barrier -> hitTestInView occlusion hides GtkOverlay.
      recordedCalls.clear();
      showBarrier.value = true;
      await tester.pump();
      expect(
        recordedCalls.any((MethodCall c) {
          if (c.method != 'setGeometry') {
            return false;
          }
          final args = c.arguments as Map<Object?, Object?>;
          return args['visible'] == false;
        }),
        isTrue,
      );

      // Remove Stack barrier -> restores visibility.
      recordedCalls.clear();
      showBarrier.value = false;
      await tester.pump();
      expect(
        recordedCalls.any((MethodCall c) {
          if (c.method != 'setGeometry') {
            return false;
          }
          final args = c.arguments as Map<Object?, Object?>;
          return args['visible'] == true;
        }),
        isTrue,
      );

      // Push a modal dialog route -> ModalRoute.isCurrentOf becomes false -> hides immediately.
      recordedCalls.clear();
      final dialogFuture = Navigator.of(pageContext).push<void>(
        RawDialogRoute<void>(
          pageBuilder: (BuildContext ctx, _, _) {
            return const Center(child: SizedBox(width: 200, height: 120));
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(
        recordedCalls.any((MethodCall c) {
          if (c.method != 'setGeometry') {
            return false;
          }
          final args = c.arguments as Map<Object?, Object?>;
          return args['visible'] == false;
        }),
        isTrue,
      );

      // Pop modal dialog -> restores visibility.
      recordedCalls.clear();
      Navigator.of(pageContext).pop();
      await dialogFuture;
      await tester.pumpAndSettle();
      expect(
        recordedCalls.any((MethodCall c) {
          if (c.method != 'setGeometry') {
            return false;
          }
          final args = c.arguments as Map<Object?, Object?>;
          return args['visible'] == true;
        }),
        isTrue,
      );

      showBarrier.dispose();
      await controller.dispose();
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'Windows host mounts Texture and forwards controller, pointer modifier, key, and wheel calls',
    (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      String? receivedJsMessage;
      String? finishedUrl;
      WebResourceError? receivedError;

      final controller = WebViewController();
      await controller.addJavaScriptChannel(
        'ChannelA',
        onMessageReceived: (JavaScriptMessage m) {
          receivedJsMessage = m.message;
        },
      );
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) => finishedUrl = url,
          onWebResourceError: (WebResourceError err) => receivedError = err,
          onNavigationRequest: (NavigationRequest req) {
            return req.url.startsWith('https://blocked.example')
                ? NavigationDecision.prevent
                : NavigationDecision.navigate;
          },
        ),
      );

      final externalFocus = FocusNode(debugLabel: 'ExternalInput');

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(devicePixelRatio: 2.0),
            child: Column(
              children: <Widget>[
                Focus(
                  focusNode: externalFocus,
                  child: const SizedBox(width: 40, height: 20),
                ),
                SizedBox(
                  width: 320,
                  height: 200,
                  child: WebView(controller: controller),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Texture), findsOneWidget);

      final sizeCalls = recordedCalls.where((MethodCall c) {
        return c.method == 'setSize';
      }).toList();
      expect(sizeCalls, isNotEmpty);
      final sizeArgs = sizeCalls.last.arguments as Map<Object?, Object?>;
      expect(sizeArgs['width'], 640);
      expect(sizeArgs['height'], 400);
      expect(sizeArgs['scaleFactor'], 2.0);

      // Exercise controller API calls once mounted.
      await controller.loadRequest(
        Uri.parse('https://keyscope.dev'),
        method: LoadRequestMethod.post,
        headers: const <String, String>{'X-Test': '1'},
        body: Uint8List.fromList(<int>[1, 2, 3]),
      );
      await controller.loadFile('/tmp/demo.html');
      await controller.setBackgroundColor(const Color(0xFFFFFFFF));
      await controller.runJavaScript('console.log(1)');
      expect(await controller.evaluateJavaScript('6 * 7'), '42');
      expect(await controller.canGoBack(), isTrue);
      expect(await controller.canGoForward(), isFalse);
      await controller.goBack();
      await controller.goForward();
      await controller.reload();
      await controller.stopLoading();
      expect(await controller.currentUrl(), 'https://keyscope.dev/docs');
      expect(await controller.getTitle(), 'Keyscope Docs');
      await controller.scrollTo(0, 100);
      await controller.scrollBy(0, 20);
      expect(await controller.getScrollPosition(), const Offset(12, 48));
      await controller.clearCache();
      await controller.clearLocalStorage();

      // Exercise Shift+click pointer modifier, keyboard shortcut, focus loss, and wheel.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.byType(Texture));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(
        recordedCalls.any((MethodCall c) {
          if (c.method != 'pointerEvent') {
            return false;
          }
          final args = c.arguments as Map<Object?, Object?>;
          return args['kind'] == 'down' && args['shift'] == true;
        }),
        isTrue,
      );

      // Send Ctrl+C while WebView holds Flutter focus.
      recordedCalls.clear();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(
        recordedCalls.any((MethodCall c) {
          if (c.method != 'keyEvent') {
            return false;
          }
          final args = c.arguments as Map<Object?, Object?>;
          return args['control'] == true && args['logicalKey'] == 'C';
        }),
        isTrue,
      );

      // Move focus away -> setFocus(focused: false).
      recordedCalls.clear();
      externalFocus.requestFocus();
      await tester.pump();
      expect(
        recordedCalls.any((MethodCall c) {
          if (c.method != 'setFocus') {
            return false;
          }
          final args = c.arguments as Map<Object?, Object?>;
          return args['focused'] == false;
        }),
        isTrue,
      );

      await tester.sendEventToBinding(
        const PointerScrollEvent(
          position: Offset(400, 120),
          scrollDelta: Offset(0, 40),
        ),
      );
      await tester.pump();
      expect(
        recordedCalls.any((MethodCall c) => c.method == 'pointerEvent'),
        isTrue,
      );

      // Simulate native -> Dart callbacks over the shared channel.
      const codec = StandardMethodCodec();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      Future<ByteData?> sendFromNative(
        String method,
        Map<String, Object?> args,
      ) {
        final encoded = codec.encodeMethodCall(MethodCall(method, args));
        return messenger.handlePlatformMessage(
          'com.infradise.webview_core',
          encoded,
          null,
        );
      }

      await sendFromNative('onJavaScriptMessage', <String, Object?>{
        'controllerId': controller.controllerId,
        'channel': 'ChannelA',
        'message': 'hello-from-native',
      });
      expect(receivedJsMessage, 'hello-from-native');

      await sendFromNative('onPageFinished', <String, Object?>{
        'controllerId': controller.controllerId,
        'url': 'https://keyscope.dev/ready',
      });
      expect(finishedUrl, 'https://keyscope.dev/ready');

      await sendFromNative('onWebResourceError', <String, Object?>{
        'controllerId': controller.controllerId,
        'errorCode': -2,
        'description': 'Host lookup failed',
        'errorType': 'hostLookup',
        'isForMainFrame': true,
        'url': 'https://offline.example',
      });
      expect(receivedError?.errorType, WebResourceErrorType.hostLookup);

      final blockedReply =
          await sendFromNative('onNavigationRequest', <String, Object?>{
            'controllerId': controller.controllerId,
            'url': 'https://blocked.example/path',
            'isMainFrame': true,
          });
      expect(codec.decodeEnvelope(blockedReply!), isFalse);

      final allowedReply =
          await sendFromNative('onNavigationRequest', <String, Object?>{
            'controllerId': controller.controllerId,
            'url': 'https://keyscope.dev/allowed',
            'isMainFrame': true,
          });
      expect(codec.decodeEnvelope(allowedReply!), isTrue);

      externalFocus.dispose();
      await controller.dispose();
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'Windows host does not swallow Tab, function keys, modifier-only or Meta combos',
    (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      final controller = WebViewController();
      await controller.loadHtmlString('<p>keys</p>');

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 200,
            height: 100,
            child: WebViewWidget(controller: controller),
          ),
        ),
      );
      await tester.pump();

      // Give the WebView host keyboard focus.
      await tester.tap(find.byType(Texture));
      await tester.pump();

      Iterable<MethodCall> keyCalls() =>
          recordedCalls.where((MethodCall c) => c.method == 'keyEvent');

      // Letters are forwarded to WebView2 and consumed.
      recordedCalls.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();
      expect(keyCalls(), isNotEmpty);

      // Tab, F-keys, Escape, and modifier-only presses must stay with Flutter.
      for (final key in <LogicalKeyboardKey>[
        LogicalKeyboardKey.tab,
        LogicalKeyboardKey.f5,
        LogicalKeyboardKey.escape,
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.controlLeft,
      ]) {
        recordedCalls.clear();
        await tester.sendKeyEvent(key);
        await tester.pump();
        expect(
          keyCalls(),
          isEmpty,
          reason: '${key.keyLabel} must pass through',
        );
      }

      // Windows-key (Meta) combinations must stay with the application.
      recordedCalls.clear();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(keyCalls(), isEmpty);

      await controller.dispose();
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'Windows host releases active mouse buttons before leave on PointerCancelEvent',
    (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      final controller = WebViewController();
      await controller.loadHtmlString('<p>cancel</p>');

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 200,
            height: 100,
            child: WebViewWidget(controller: controller),
          ),
        ),
      );
      await tester.pump();

      recordedCalls.clear();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Texture)),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.cancel();
      await tester.pump();

      final pointerKinds = recordedCalls
          .where((MethodCall c) => c.method == 'pointerEvent')
          .map((MethodCall c) {
            final args = c.arguments as Map<Object?, Object?>;
            return '${args['kind']}:${args['button']}';
          })
          .toList();
      expect(
        pointerKinds,
        containsAllInOrder(<String>['down:1', 'up:1', 'leave:0']),
      );

      await controller.dispose();
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
