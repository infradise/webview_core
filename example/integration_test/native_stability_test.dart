import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:webview_core/webview_core.dart';

/// Real-native regression tests (no mocked channel): they drive the actual
/// `WKWebView` / WebKitGTK / WebView2 plugin through the same lifecycle events
/// Keyscope produces (tab hide/show, remounts, rounded clips, resize, theme
/// toggles, rapid HTML reloads).
const String _kBase = 'https://webview-core-test.invalid/docs/';

String _html(int n, {String body = 'Hello'}) =>
    '<!DOCTYPE html><html><head><meta charset="utf-8"><title>T$n</title></head>'
    '<body style="margin:0"><h1 id="h">$body $n</h1></body></html>';

Future<T> _guard<T>(Future<T> f, String what) => f.timeout(
  const Duration(seconds: 8),
  onTimeout: () => throw TimeoutException('NATIVE HANG: $what'),
);

class _Harness extends StatefulWidget {
  const _Harness({required this.controller, required this.tab});

  final WebViewController controller;
  final ValueNotifier<int> tab;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  @override
  void initState() {
    super.initState();
    widget.tab.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    widget.tab.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: IndexedStack(
        index: widget.tab.value,
        children: <Widget>[
          SizedBox.expand(child: WebViewWidget(controller: widget.controller)),
          const ColoredBox(color: Color(0xFF123456), child: SizedBox.expand()),
        ],
      ),
    );
  }
}

/// Mail Sender-like layout: editor on the left, rounded-clip preview on the
/// right whose width, visibility, and theme change while the page reloads.
class _SplitState {
  const _SplitState({
    required this.rightFraction,
    required this.showPreview,
    required this.dark,
  });

  final double rightFraction;
  final bool showPreview;
  final bool dark;
}

class _SplitHarness extends StatelessWidget {
  const _SplitHarness({required this.controller, required this.state});

  final WebViewController controller;
  final ValueListenable<_SplitState> state;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ValueListenableBuilder<_SplitState>(
        valueListenable: state,
        builder: (BuildContext context, _SplitState value, Widget? _) {
          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              final right = (box.maxWidth * value.rightFraction).clamp(
                80.0,
                box.maxWidth - 80.0,
              );
              return Row(
                children: <Widget>[
                  const Expanded(
                    child: ColoredBox(
                      color: Color(0xFF222222),
                      child: SizedBox.expand(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: right,
                    child: ColoredBox(
                      color: value.dark
                          ? const Color(0xFF101418)
                          : const Color(0xFFF4F1EA),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: IndexedStack(
                            index: value.showPreview ? 0 : 1,
                            children: <Widget>[
                              SizedBox.expand(
                                child: WebViewWidget(controller: controller),
                              ),
                              const SizedBox.expand(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<WebViewController> boot(
    WidgetTester tester,
    ValueNotifier<int> tab, {
    String? html,
    String? baseUrl,
    Future<void> Function(WebViewController controller)? configure,
    void Function(String event)? onEvent,
    NavigationDecision Function(String url)? decide,
  }) async {
    final controller = WebViewController();
    final finished = Completer<void>();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    if (configure != null) {
      await configure(controller);
    }
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (String url) => onEvent?.call('started:$url'),
        onWebResourceError: (WebResourceError e) =>
            onEvent?.call('error:${e.url}'),
        onNavigationRequest: decide == null
            ? null
            : (NavigationRequest r) => decide(r.url),
        onPageFinished: (String url) {
          onEvent?.call('finished:$url');
          if (!finished.isCompleted) {
            finished.complete();
          }
        },
      ),
    );
    await controller.loadHtmlString(html ?? _html(0), baseUrl: baseUrl);
    await tester.pumpWidget(_Harness(controller: controller, tab: tab));
    for (var i = 0; i < 60 && !finished.isCompleted; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(finished.isCompleted, isTrue, reason: 'initial page never finished');
    return controller;
  }

  Future<void> settle(WidgetTester tester, {int ms = 1500}) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('A. JS round trip returns normalized scalar types', (
    tester,
  ) async {
    final tab = ValueNotifier<int>(0);
    final c = await boot(tester, tab);
    expect(await _guard(c.evaluateJavaScript('1+1'), 'int'), '2');
    expect(await _guard(c.evaluateJavaScript('1.5'), 'double'), '1.5');
    expect(await _guard(c.evaluateJavaScript('true'), 'bool'), 'true');
    expect(await _guard(c.evaluateJavaScript('"s"'), 'string'), 's');
    expect(await _guard(c.evaluateJavaScript('null'), 'null'), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await c.dispose();
  });

  testWidgets('B. native view survives IndexedStack hide/show x40', (
    tester,
  ) async {
    final tab = ValueNotifier<int>(0);
    final c = await boot(tester, tab);
    for (var i = 0; i < 40; i++) {
      tab.value = 1;
      await tester.pump(const Duration(milliseconds: 60));
      tab.value = 0;
      await tester.pump(const Duration(milliseconds: 60));
      final t = await _guard(
        c.evaluateJavaScript('document.title'),
        'title after toggle $i',
      );
      expect(t, 'T0', reason: 'iteration $i lost the document');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await c.dispose();
  });

  testWidgets('C. reload() keeps loadHtmlString content (no refetch)', (
    tester,
  ) async {
    final tab = ValueNotifier<int>(0);
    final c = await boot(
      tester,
      tab,
      html: _html(7, body: 'KEEP'),
      baseUrl: _kBase,
    );
    await c.reload();
    await settle(tester, ms: 2000);
    final t = await _guard(
      c.evaluateJavaScript(
        'document.getElementById("h") ? '
        'document.getElementById("h").innerText : "MISSING"',
      ),
      'body after reload',
    );
    expect(t, 'KEEP 7', reason: 'reload() replaced the HTML with a fetch');
    await tester.pumpWidget(const SizedBox.shrink());
    await c.dispose();
  });

  testWidgets('D. rapid loadHtmlString + setBackgroundColor storm', (
    tester,
  ) async {
    final tab = ValueNotifier<int>(0);
    final c = await boot(tester, tab);
    for (var i = 1; i <= 300; i++) {
      unawaited(c.loadHtmlString(_html(i), baseUrl: _kBase));
      unawaited(
        c.setBackgroundColor(
          i.isEven ? const Color(0xFF111111) : const Color(0xFFEEEEEE),
        ),
      );
      await tester.pump(const Duration(milliseconds: 8));
    }
    await settle(tester, ms: 3000);
    expect(
      await _guard(c.evaluateJavaScript('document.title'), 'title'),
      'T300',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await c.dispose();
  });

  testWidgets('E. unmount/remount keeps content and JS alive x20', (
    tester,
  ) async {
    final tab = ValueNotifier<int>(0);
    final c = await boot(tester, tab, html: _html(5), baseUrl: _kBase);
    for (var i = 0; i < 20; i++) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(_Harness(controller: c, tab: tab));
      await settle(tester, ms: 900);
      final t = await _guard(
        c.evaluateJavaScript('document.title'),
        'title after remount $i',
      );
      expect(t, 'T5', reason: 'remount $i lost document');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await c.dispose();
  });

  testWidgets(
    'F. ClipRRect split pane: resize + theme toggle + hide/show storm',
    (tester) async {
      final c = WebViewController();
      final finished = Completer<void>();
      await c.setJavaScriptMode(JavaScriptMode.unrestricted);
      await c.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String _) {
            if (!finished.isCompleted) {
              finished.complete();
            }
          },
        ),
      );
      await c.loadHtmlString(_html(0), baseUrl: _kBase);
      final state = ValueNotifier<_SplitState>(
        const _SplitState(rightFraction: 0.5, showPreview: true, dark: true),
      );
      await tester.pumpWidget(_SplitHarness(controller: c, state: state));
      for (var i = 0; i < 60 && !finished.isCompleted; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(finished.isCompleted, isTrue);

      for (var i = 1; i <= 300; i++) {
        final dark = (i ~/ 5).isEven;
        state.value = _SplitState(
          rightFraction: 0.5 + 0.25 * math.sin(i / 7.0),
          showPreview: i % 11 != 0,
          dark: dark,
        );
        if (i % 5 == 0) {
          unawaited(
            c.setBackgroundColor(
              dark ? const Color(0xFF101418) : const Color(0xFFF4F1EA),
            ),
          );
          unawaited(c.loadHtmlString(_html(i), baseUrl: _kBase));
        }
        await tester.pump(const Duration(milliseconds: 16));
        if (i % 50 == 0) {
          await settle(tester, ms: 800);
          expect(
            await _guard(c.evaluateJavaScript('1+1'), 'ping at $i'),
            '2',
            reason: 'native bridge died at iteration $i',
          );
        }
      }
      state.value = const _SplitState(
        rightFraction: 0.5,
        showPreview: true,
        dark: true,
      );
      await settle(tester, ms: 1500);
      expect(
        await _guard(c.evaluateJavaScript('document.title'), 'final title'),
        'T300',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await c.dispose();
      state.dispose();
    },
  );

  testWidgets('G. debounced typing storm (Mail Sender live preview)', (
    tester,
  ) async {
    final tab = ValueNotifier<int>(0);
    final c = await boot(tester, tab, baseUrl: _kBase);
    Timer? debounce;
    var latest = '';
    for (var key = 1; key <= 400; key++) {
      latest = _html(key, body: 'typing');
      debounce?.cancel();
      final snapshot = latest;
      debounce = Timer(const Duration(milliseconds: 80), () {
        unawaited(c.loadHtmlString(snapshot, baseUrl: _kBase));
      });
      if (key % 40 == 0) {
        unawaited(
          c.setBackgroundColor(
            (key ~/ 40).isEven
                ? const Color(0xFF101418)
                : const Color(0xFFF4F1EA),
          ),
        );
      }
      await tester.pump(const Duration(milliseconds: 15));
    }
    await tester.pump(const Duration(milliseconds: 200));
    await settle(tester, ms: 2000);
    debounce?.cancel();
    expect(
      await _guard(c.evaluateJavaScript('document.title'), 'title'),
      'T400',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await c.dispose();
  });

  testWidgets('H. target=_blank link opens in place', (tester) async {
    final tab = ValueNotifier<int>(0);
    final events = <String>[];
    final c = await boot(
      tester,
      tab,
      html:
          '<!DOCTYPE html><html><head><title>L</title></head><body>'
          '<a id="a" target="_blank" '
          'href="https://webview-core-test.invalid/next">x</a></body></html>',
      baseUrl: _kBase,
      onEvent: events.add,
    );
    events.clear();
    await c.runJavaScript('document.getElementById("a").click()');
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (events.any((String e) => e.contains('/next'))) {
        break;
      }
    }
    expect(
      events.any((String e) => e.contains('/next')),
      isTrue,
      reason: 'target=_blank click was dropped: $events',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await c.dispose();
  });

  testWidgets('I. JS channel delivery and navigation prevention', (
    tester,
  ) async {
    final tab = ValueNotifier<int>(0);
    final events = <String>[];
    final message = Completer<String>();
    final c = await boot(
      tester,
      tab,
      html: _html(1),
      baseUrl: _kBase,
      onEvent: events.add,
      decide: (String url) => url.contains('blocked')
          ? NavigationDecision.prevent
          : NavigationDecision.navigate,
      configure: (WebViewController controller) =>
          controller.addJavaScriptChannel(
            'Bridge',
            onMessageReceived: (JavaScriptMessage m) {
              if (!message.isCompleted) {
                message.complete(m.message);
              }
            },
          ),
    );
    await c.loadHtmlString(_html(2), baseUrl: _kBase);
    await settle(tester);
    await c.runJavaScript('Bridge.postMessage("ping-" + document.title)');
    for (var i = 0; i < 30 && !message.isCompleted; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      message.isCompleted,
      isTrue,
      reason: 'channel message not delivered',
    );
    expect(await message.future, 'ping-T2');

    events.clear();
    await c.runJavaScript(
      'location.href="https://webview-core-test.invalid/blocked"',
    );
    await settle(tester);
    expect(
      await _guard(c.evaluateJavaScript('document.title'), 'title'),
      'T2',
      reason: 'prevented navigation replaced the document: $events',
    );
    expect(events.any((String e) => e.contains('/blocked')), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await c.dispose();
  });

  testWidgets('J. cookie manager round trip', (tester) async {
    final manager = WebViewCookieManager();
    await manager.setCookie(
      const WebViewCookie(
        name: 'wvcore',
        value: 'ok',
        domain: 'webview-core-test.invalid',
      ),
    );
    final tab = ValueNotifier<int>(0);
    final c = await boot(tester, tab, html: _html(3), baseUrl: _kBase);
    expect(
      await _guard(c.evaluateJavaScript('document.cookie'), 'cookie'),
      contains('wvcore=ok'),
    );
    expect(await manager.clearCookies(), isTrue);
    await c.loadHtmlString(_html(4), baseUrl: _kBase);
    await settle(tester);
    expect(
      await _guard(c.evaluateJavaScript('document.cookie'), 'cookie2'),
      isNot(contains('wvcore=ok')),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await c.dispose();
  });
}
