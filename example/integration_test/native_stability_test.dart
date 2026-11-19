import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:webview_core/webview_core.dart';

final class _GList extends ffi.Struct {
  external ffi.Pointer<ffi.Void> data;
  external ffi.Pointer<_GList> next;
  external ffi.Pointer<_GList> prev;
}

final class _GdkEventButton extends ffi.Struct {
  @ffi.Int32()
  external int type;
  external ffi.Pointer<ffi.Void> window;
  @ffi.Int8()
  external int sendEvent;
  @ffi.Uint32()
  external int time;
  @ffi.Double()
  external double x;
  @ffi.Double()
  external double y;
  external ffi.Pointer<ffi.Double> axes;
  @ffi.Uint32()
  external int state;
  @ffi.Uint32()
  external int button;
  external ffi.Pointer<ffi.Void> device;
  @ffi.Double()
  external double xRoot;
  @ffi.Double()
  external double yRoot;
}

class _LinuxGtkProbe {
  _LinuxGtkProbe()
    : _gtk = ffi.DynamicLibrary.open('libgtk-3.so.0'),
      _gdk = ffi.DynamicLibrary.open('libgdk-3.so.0'),
      _gobject = ffi.DynamicLibrary.open('libgobject-2.0.so.0'),
      _glib = ffi.DynamicLibrary.open('libglib-2.0.so.0');

  final ffi.DynamicLibrary _gtk;
  final ffi.DynamicLibrary _gdk;
  final ffi.DynamicLibrary _gobject;
  final ffi.DynamicLibrary _glib;

  late final ffi.Pointer<_GList> Function() listToplevels = _gtk
      .lookupFunction<
        ffi.Pointer<_GList> Function(),
        ffi.Pointer<_GList> Function()
      >('gtk_window_list_toplevels');

  late final void Function(ffi.Pointer<_GList>) gListFree = _glib
      .lookupFunction<
        ffi.Void Function(ffi.Pointer<_GList>),
        void Function(ffi.Pointer<_GList>)
      >('g_list_free');

  late final ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>) getFocus =
      _gtk.lookupFunction<
        ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>),
        ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>)
      >('gtk_window_get_focus');

  late final void Function(ffi.Pointer<ffi.Void>) grabFocus = _gtk
      .lookupFunction<
        ffi.Void Function(ffi.Pointer<ffi.Void>),
        void Function(ffi.Pointer<ffi.Void>)
      >('gtk_widget_grab_focus');

  late final int Function(ffi.Pointer<ffi.Void>) isFocus = _gtk
      .lookupFunction<
        ffi.Int32 Function(ffi.Pointer<ffi.Void>),
        int Function(ffi.Pointer<ffi.Void>)
      >('gtk_widget_is_focus');

  late final int Function(ffi.Pointer<ffi.Void>) getMapped = _gtk
      .lookupFunction<
        ffi.Int32 Function(ffi.Pointer<ffi.Void>),
        int Function(ffi.Pointer<ffi.Void>)
      >('gtk_widget_get_mapped');

  late final int Function() containerType = _gtk
      .lookupFunction<ffi.Size Function(), int Function()>(
        'gtk_container_get_type',
      );

  late final int Function(ffi.Pointer<ffi.Void>, int) isA = _gobject
      .lookupFunction<
        ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Size),
        int Function(ffi.Pointer<ffi.Void>, int)
      >('g_type_check_instance_is_a');

  late final ffi.Pointer<_GList> Function(ffi.Pointer<ffi.Void>) getChildren =
      _gtk.lookupFunction<
        ffi.Pointer<_GList> Function(ffi.Pointer<ffi.Void>),
        ffi.Pointer<_GList> Function(ffi.Pointer<ffi.Void>)
      >('gtk_container_get_children');

  late final ffi.Pointer<ffi.Char> Function(int) gTypeName = _gobject
      .lookupFunction<
        ffi.Pointer<ffi.Char> Function(ffi.Size),
        ffi.Pointer<ffi.Char> Function(int)
      >('g_type_name');

  late final int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<_GdkEventButton>)
  widgetEvent = _gtk
      .lookupFunction<
        ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Pointer<_GdkEventButton>),
        int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<_GdkEventButton>)
      >('gtk_widget_event');

  late final ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>)
  widgetGetWindow = _gtk
      .lookupFunction<
        ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>),
        ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>)
      >('gtk_widget_get_window');

  late final ffi.Pointer<_GdkEventButton> Function(int) gdkEventNew = _gdk
      .lookupFunction<
        ffi.Pointer<_GdkEventButton> Function(ffi.Int32),
        ffi.Pointer<_GdkEventButton> Function(int)
      >('gdk_event_new');

  late final void Function(ffi.Pointer<_GdkEventButton>) gdkEventFree = _gdk
      .lookupFunction<
        ffi.Void Function(ffi.Pointer<_GdkEventButton>),
        void Function(ffi.Pointer<_GdkEventButton>)
      >('gdk_event_free');

  late final ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>) gObjectRef =
      _gobject.lookupFunction<
        ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>),
        ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>)
      >('g_object_ref');

  late final ffi.Pointer<ffi.Void> Function() gdkDisplayGetDefault = _gdk
      .lookupFunction<
        ffi.Pointer<ffi.Void> Function(),
        ffi.Pointer<ffi.Void> Function()
      >('gdk_display_get_default');

  late final ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>)
  gdkDisplayGetDefaultSeat = _gdk
      .lookupFunction<
        ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>),
        ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>)
      >('gdk_display_get_default_seat');

  late final ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>)
  gdkSeatGetPointer = _gdk
      .lookupFunction<
        ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>),
        ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>)
      >('gdk_seat_get_pointer');

  late final void Function(ffi.Pointer<_GdkEventButton>, ffi.Pointer<ffi.Void>)
  gdkEventSetDevice = _gdk
      .lookupFunction<
        ffi.Void Function(ffi.Pointer<_GdkEventButton>, ffi.Pointer<ffi.Void>),
        void Function(ffi.Pointer<_GdkEventButton>, ffi.Pointer<ffi.Void>)
      >('gdk_event_set_device');

  late final void Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Int32>,
  )
  gdkWindowGetPosition = _gdk
      .lookupFunction<
        ffi.Void Function(
          ffi.Pointer<ffi.Void>,
          ffi.Pointer<ffi.Int32>,
          ffi.Pointer<ffi.Int32>,
        ),
        void Function(
          ffi.Pointer<ffi.Void>,
          ffi.Pointer<ffi.Int32>,
          ffi.Pointer<ffi.Int32>,
        )
      >('gdk_window_get_position');

  late final ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>)
  gdkWindowGetParent = _gdk
      .lookupFunction<
        ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>),
        ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>)
      >('gdk_window_get_parent');

  late final ffi.Pointer<ffi.Void> Function(int, int) _calloc =
      ffi.DynamicLibrary.process().lookupFunction<
        ffi.Pointer<ffi.Void> Function(ffi.Size, ffi.Size),
        ffi.Pointer<ffi.Void> Function(int, int)
      >('calloc');

  late final void Function(ffi.Pointer<ffi.Void>) _free =
      ffi.DynamicLibrary.process().lookupFunction<
        ffi.Void Function(ffi.Pointer<ffi.Void>),
        void Function(ffi.Pointer<ffi.Void>)
      >('free');

  String typeNameOf(ffi.Pointer<ffi.Void> instance) {
    if (instance == ffi.nullptr) {
      return '';
    }
    final gClass = instance.cast<ffi.Pointer<ffi.Size>>().value;
    if (gClass == ffi.nullptr) {
      return '';
    }
    final namePtr = gTypeName(gClass.value).cast<ffi.Uint8>();
    if (namePtr == ffi.nullptr) {
      return '';
    }
    final units = <int>[];
    for (var i = 0; i < 128; i++) {
      final b = namePtr[i];
      if (b == 0) {
        break;
      }
      units.add(b);
    }
    return String.fromCharCodes(units);
  }

  ffi.Pointer<ffi.Void> firstToplevelWindow() {
    final list = listToplevels();
    if (list == ffi.nullptr) {
      return ffi.nullptr;
    }
    try {
      var cur = list;
      while (cur != ffi.nullptr) {
        final w = cur.ref.data;
        if (w != ffi.nullptr && getMapped(w) != 0) {
          return w;
        }
        cur = cur.ref.next;
      }
      return list.ref.data;
    } finally {
      gListFree(list);
    }
  }

  ffi.Pointer<ffi.Void> findByTypeName(
    ffi.Pointer<ffi.Void> root,
    String targetType,
  ) {
    if (root == ffi.nullptr) {
      return ffi.nullptr;
    }
    if (typeNameOf(root) == targetType) {
      return root;
    }
    if (isA(root, containerType()) == 0) {
      return ffi.nullptr;
    }
    final children = getChildren(root);
    if (children == ffi.nullptr) {
      return ffi.nullptr;
    }
    try {
      var cur = children;
      while (cur != ffi.nullptr) {
        final found = findByTypeName(cur.ref.data, targetType);
        if (found != ffi.nullptr) {
          return found;
        }
        cur = cur.ref.next;
      }
      return ffi.nullptr;
    } finally {
      gListFree(children);
    }
  }

  int toplevelRelativeY(
    ffi.Pointer<ffi.Void> widget,
    ffi.Pointer<ffi.Void> toplevel,
  ) {
    final topWin = widgetGetWindow(toplevel);
    var cur = widgetGetWindow(widget);
    var sumY = 0;
    final dx = _calloc(1, ffi.sizeOf<ffi.Int32>()).cast<ffi.Int32>();
    final dy = _calloc(1, ffi.sizeOf<ffi.Int32>()).cast<ffi.Int32>();
    try {
      while (cur != ffi.nullptr && topWin != ffi.nullptr && cur != topWin) {
        dx.value = 0;
        dy.value = 0;
        gdkWindowGetPosition(cur, dx, dy);
        sumY += dy.value;
        cur = gdkWindowGetParent(cur);
      }
      return sumY;
    } finally {
      _free(dx.cast());
      _free(dy.cast());
    }
  }

  void sendClickToWidget(ffi.Pointer<ffi.Void> widget) {
    final gdkWin = widgetGetWindow(widget);
    final display = gdkDisplayGetDefault();
    final seat = display != ffi.nullptr
        ? gdkDisplayGetDefaultSeat(display)
        : ffi.nullptr;
    final pointer = seat != ffi.nullptr ? gdkSeatGetPointer(seat) : ffi.nullptr;
    for (final evType in <int>[4, 7]) {
      final ev = gdkEventNew(evType);
      if (ev == ffi.nullptr) {
        continue;
      }
      try {
        if (pointer != ffi.nullptr) {
          gdkEventSetDevice(ev, pointer);
        }
        ev.ref
          ..type = evType
          ..window = gdkWin != ffi.nullptr ? gObjectRef(gdkWin) : ffi.nullptr
          ..button = 1
          ..x = 10.0
          ..y = 10.0;
        widgetEvent(widget, ev);
      } finally {
        gdkEventFree(ev);
      }
    }
  }
}

/// Real-native regression tests (no mocked channel): they drive the actual
/// `WKWebView` / WebKitGTK / WebView2 plugin through typical multi-tab desktop
/// app lifecycles (tab hide/show, remounts, rounded clips, resize, theme
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

  /// Polls [script] until it evaluates to [expected]. Asynchronous page loads
  /// take very different times on developer machines and CI runners, so tests
  /// wait for the observable condition instead of sleeping a fixed time.
  Future<void> waitForJs(
    WidgetTester tester,
    WebViewController c,
    String script,
    String expected, {
    String reason = '',
  }) async {
    String? last;
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      last = await _guard(c.evaluateJavaScript(script), 'poll $script');
      if (last == expected) {
        return;
      }
    }
    fail(
      'Timed out waiting for `$script` == "$expected" (last "$last"). $reason',
    );
  }

  Future<void> waitForTitle(
    WidgetTester tester,
    WebViewController c,
    String expected, {
    String reason = '',
  }) => waitForJs(tester, c, 'document.title', expected, reason: reason);

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
    await waitForJs(
      tester,
      c,
      'document.getElementById("h") ? '
          'document.getElementById("h").innerText : "MISSING"',
      'KEEP 7',
      reason: 'reload() replaced the HTML with a fetch',
    );
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
    await waitForTitle(tester, c, 'T300');
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
      await waitForTitle(tester, c, 'T5', reason: 'remount $i lost document');
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
      await waitForTitle(tester, c, 'T300');
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
    await waitForTitle(tester, c, 'T400');
    debounce?.cancel();
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
    await waitForTitle(tester, c, 'T2');
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
    await waitForTitle(tester, c, 'T4');
    expect(
      await _guard(c.evaluateJavaScript('document.cookie'), 'cookie2'),
      isNot(contains('wvcore=ok')),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await c.dispose();
  });

  testWidgets('K. loadHtmlString baseUrl gives the page its real origin', (
    tester,
  ) async {
    final tab = ValueNotifier<int>(0);
    final c = await boot(tester, tab, html: _html(8), baseUrl: _kBase);
    expect(
      await _guard(c.evaluateJavaScript('window.origin'), 'origin'),
      'https://webview-core-test.invalid',
      reason: 'document got an opaque origin instead of the baseUrl origin',
    );
    expect(
      await _guard(
        c.evaluateJavaScript(
          '(function(){try{localStorage.setItem("k","v");'
          'return localStorage.getItem("k")}catch(e){return e.name}})()',
        ),
        'localStorage',
      ),
      'v',
      reason: 'localStorage must work for a document with a baseUrl origin',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await c.dispose();
  });

  testWidgets(
    'L. right click (context menu) does not stall the native bridge',
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
      await c.loadHtmlString(
        '<!DOCTYPE html><html><body style="margin:0"><div style="height:400px">'
        'hello<script>window.__cm=0;'
        'document.addEventListener("contextmenu",function(){window.__cm++});'
        '</script></div></body></html>',
        baseUrl: _kBase,
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.expand(child: WebViewWidget(controller: c)),
        ),
      );
      for (var i = 0; i < 60 && !finished.isCompleted; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        finished.isCompleted,
        isTrue,
        reason: 'initial page never finished',
      );
      await settle(tester, ms: 1000);

      final center = tester.getCenter(find.byType(WebViewWidget));
      final gesture = await tester.startGesture(
        center,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await settle(tester, ms: 1500);

      // A context menu shown synchronously inside the WebView2 event handler
      // blocks every later native call until the menu is closed.
      expect(
        await _guard(c.evaluateJavaScript('1+1'), 'eval after right click'),
        '2',
        reason: 'native bridge stalled after a right click',
      );
      if (defaultTargetPlatform == TargetPlatform.windows) {
        await waitForJs(
          tester,
          c,
          'String(window.__cm)',
          '1',
          reason: 'right click never reached the page',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await c.dispose();
    },
  );

  testWidgets(
    'M. left click reaches DOM and sibling Flutter controls remain responsive',
    (tester) async {
      var siblingTaps = 0;
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
      await c.loadHtmlString(
        '<!DOCTYPE html><html><body style="margin:0">'
        '<div id="pad" onclick="window.__clicks=(window.__clicks||0)+1" '
        'style="width:100vw;height:100vh">click target</div>'
        '</body></html>',
        baseUrl: _kBase,
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: <Widget>[
              GestureDetector(
                key: const ValueKey<String>('sibling_btn'),
                behavior: HitTestBehavior.opaque,
                onTap: () => siblingTaps++,
                child: const SizedBox(width: 300, height: 48),
              ),
              Expanded(child: WebViewWidget(controller: c)),
            ],
          ),
        ),
      );
      for (var i = 0; i < 60 && !finished.isCompleted; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        finished.isCompleted,
        isTrue,
        reason: 'initial page never finished',
      );

      await tester.tap(
        find.byType(WebViewWidget),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (defaultTargetPlatform == TargetPlatform.windows) {
        await waitForJs(
          tester,
          c,
          'String(window.__clicks||0)',
          '1',
          reason: 'left click never reached DOM in composition host',
        );
      }

      await tester.tap(
        find.byKey(const ValueKey<String>('sibling_btn')),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      expect(siblingTaps, 1, reason: 'sibling Flutter control stopped working');

      await tester.pumpWidget(const SizedBox.shrink());
      await c.dispose();
    },
  );

  testWidgets('N. focus recovery, RepaintBoundary shift, and partial popup occlusion', (
    tester,
  ) async {
    Future<void> pollCondition(bool Function() predicate) async {
      for (var i = 0; i < 60 && !predicate(); i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    var flutterSurfaceClicks = 0;
    final tab = ValueNotifier<int>(0);
    final showPopup = ValueNotifier<bool>(false);
    final topPad = ValueNotifier<double>(48.0);
    final c = WebViewController();
    await c.setJavaScriptMode(JavaScriptMode.unrestricted);
    await c.loadHtmlString(_html(14), baseUrl: _kBase);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder<int>(
          valueListenable: tab,
          builder: (BuildContext context, int activeTab, Widget? _) {
            return IndexedStack(
              index: activeTab,
              children: <Widget>[
                ValueListenableBuilder<double>(
                  valueListenable: topPad,
                  builder: (BuildContext context, double top, Widget? child) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: showPopup,
                      builder: (BuildContext context, bool popup, Widget? web) {
                        return Stack(
                          children: <Widget>[
                            Positioned(
                              left: 0,
                              top: 0,
                              width: 200,
                              height: 40,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => flutterSurfaceClicks++,
                                child: const ColoredBox(
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 16,
                              top: top,
                              width: 320,
                              height: 200,
                              child: web!,
                            ),
                            if (popup)
                              const Positioned(
                                left: 120,
                                top: 24,
                                width: 180,
                                height: 120,
                                child: AbsorbPointer(
                                  child: ColoredBox(color: Color(0xFF1E293B)),
                                ),
                              ),
                          ],
                        );
                      },
                      child: child,
                    );
                  },
                  child: RepaintBoundary(child: WebViewWidget(controller: c)),
                ),
                const ColoredBox(
                  color: Color(0xFF0F172A),
                  child: SizedBox.expand(),
                ),
              ],
            );
          },
        ),
      ),
    );

    await waitForTitle(
      tester,
      c,
      'T14',
      reason: 'initial page in Test N never finished loading',
    );

    if (Platform.isLinux) {
      final gtk = _LinuxGtkProbe();
      final win = gtk.firstToplevelWindow();
      final flView = gtk.findByTypeName(win, 'FlView');
      final eventBox = gtk.findByTypeName(flView, 'GtkEventBox');
      final clipBox = gtk.findByTypeName(flView, 'WebviewClipBox');
      final webView = gtk.findByTypeName(flView, 'WebKitWebView');

      expect(flView, isNot(ffi.nullptr));
      expect(eventBox, isNot(ffi.nullptr));
      expect(clipBox, isNot(ffi.nullptr));
      expect(webView, isNot(ffi.nullptr));
      await pollCondition(() => gtk.getMapped(clipBox) != 0);
      expect(
        gtk.getMapped(clipBox),
        isNonZero,
        reason: 'WebviewClipBox must be mapped on Wayland/X11 when visible',
      );

      // 1) Pure vertical shift across RepaintBoundary (fixed 320x200 size):
      // native GdkWindow (including Wayland subsurface) must move by +48px.
      final yBefore = gtk.toplevelRelativeY(clipBox, win);
      topPad.value = 96.0;
      await tester.pump();
      await pollCondition(
        () => gtk.toplevelRelativeY(clipBox, win) == yBefore + 48,
      );
      expect(
        gtk.toplevelRelativeY(clipBox, win),
        yBefore + 48,
        reason:
            'Pure ancestor translation across RepaintBoundary must move native overlay window',
      );

      // 2) Simulate native WebKitWebView grabbing GTK focus on user click,
      // then click Flutter's GtkEventBox once -> FlView must reclaim focus
      // AND deliver the click to the Flutter GestureDetector on the same tap.
      gtk.grabFocus(webView);
      await pollCondition(() => gtk.isFocus(webView) != 0);
      expect(gtk.isFocus(webView), isNonZero);

      final binding = tester.binding;
      final liveBinding = binding is LiveTestWidgetsFlutterBinding
          ? binding
          : null;
      final prevPropagate =
          liveBinding?.shouldPropagateDevicePointerEvents ?? false;
      try {
        liveBinding?.shouldPropagateDevicePointerEvents = true;
        gtk.sendClickToWidget(eventBox);
        await pollCondition(
          () => gtk.isFocus(flView) != 0 && flutterSurfaceClicks == 1,
        );
      } finally {
        liveBinding?.shouldPropagateDevicePointerEvents = prevPropagate;
      }
      expect(
        gtk.getFocus(win),
        flView,
        reason:
            'Single click on Flutter surface must restore GTK focus to FlView',
      );
      expect(
        flutterSurfaceClicks,
        1,
        reason:
            'Single click on Flutter surface must also reach Flutter GestureDetector',
      );

      // 3) Grab focus onto WebKitWebView again, then hide via IndexedStack ->
      // setGeometry(visible: false) must restore focus to FlView & unmap clipBox.
      gtk.grabFocus(webView);
      await pollCondition(() => gtk.isFocus(webView) != 0);
      expect(gtk.isFocus(webView), isNonZero);

      tab.value = 1;
      await tester.pump();
      await pollCondition(
        () => gtk.getMapped(clipBox) == 0 && gtk.isFocus(flView) != 0,
      );
      expect(
        gtk.getMapped(clipBox),
        0,
        reason: 'Hidden WebView clip container must unmap immediately',
      );
      expect(
        gtk.getFocus(win),
        flView,
        reason: 'Hiding focused WebView must restore GTK focus to FlView',
      );

      // 4) Partial popup occlusion must unmap clipBox and restore when closed.
      tab.value = 0;
      await tester.pump();
      await pollCondition(() => gtk.getMapped(clipBox) != 0);
      expect(gtk.getMapped(clipBox), isNonZero);

      showPopup.value = true;
      await tester.pump();
      await pollCondition(() => gtk.getMapped(clipBox) == 0);
      expect(
        gtk.getMapped(clipBox),
        0,
        reason: 'Partially occluding Flutter popup must unmap native overlay',
      );

      showPopup.value = false;
      await tester.pump();
      await pollCondition(() => gtk.getMapped(clipBox) != 0);
      expect(gtk.getMapped(clipBox), isNonZero);
    } else {
      topPad.value = 96.0;
      await tester.pump(const Duration(milliseconds: 100));
      showPopup.value = true;
      await tester.pump(const Duration(milliseconds: 100));
      showPopup.value = false;
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(await _guard(c.evaluateJavaScript('document.title'), 'T14'), 'T14');

    tab.dispose();
    showPopup.dispose();
    topPad.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await c.dispose();
  });

  testWidgets(
    'O. macOS orphan & menu-tracking trackpad scroll phases do not crash FlutterViewController',
    (WidgetTester tester) async {
      final splitState = ValueNotifier<_SplitState>(
        const _SplitState(rightFraction: 0.5, showPreview: true, dark: true),
      );
      final c = WebViewController();
      final finished = Completer<void>();
      await c.setJavaScriptMode(JavaScriptMode.unrestricted);
      await c.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!finished.isCompleted) {
              finished.complete();
            }
          },
        ),
      );
      await c.loadHtmlString(
        _html(15, body: 'ContextMenuScroll'),
        baseUrl: _kBase,
      );
      await tester.pumpWidget(_SplitHarness(controller: c, state: splitState));
      for (var i = 0; i < 60 && !finished.isCompleted; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        finished.isCompleted,
        isTrue,
        reason: 'initial page never finished',
      );

      if (defaultTargetPlatform == TargetPlatform.macOS) {
        await waitForTitle(tester, c, 'T15', reason: 'WKWebView ready');
        // Give AppKit one frame to attach InteractiveWKWebView to FlutterMutatorView.
        await tester.pump(const Duration(milliseconds: 100));

        final sentCount = _exerciseMacOSOrphanTrackpadScrollPhases();
        expect(
          sentCount,
          12,
          reason:
              'Failed to synthesize all 12 orphan and NSEventTrackingRunLoopMode scroll phases',
        );
        await tester.pump(const Duration(milliseconds: 100));

        await waitForJs(
          tester,
          c,
          'document.getElementById("h").textContent',
          'ContextMenuScroll 15',
          reason: 'WKWebView stopped responding after orphan trackpad phases',
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await c.dispose();
      splitState.dispose();
    },
  );
}

typedef _ObjcGetClassNative =
    ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Char>);
typedef _ObjcGetClassDart =
    ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Char>);
typedef _SelRegisterNameNative =
    ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Char>);
typedef _SelRegisterNameDart =
    ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Char>);
typedef _MsgSend0Native =
    ffi.Pointer<ffi.Void> Function(
      ffi.Pointer<ffi.Void>,
      ffi.Pointer<ffi.Void>,
    );
typedef _MsgSend0Dart =
    ffi.Pointer<ffi.Void> Function(
      ffi.Pointer<ffi.Void>,
      ffi.Pointer<ffi.Void>,
    );
typedef _MsgSendPtrNative =
    ffi.Pointer<ffi.Void> Function(
      ffi.Pointer<ffi.Void>,
      ffi.Pointer<ffi.Void>,
      ffi.Pointer<ffi.Void>,
    );
typedef _MsgSendPtrDart =
    ffi.Pointer<ffi.Void> Function(
      ffi.Pointer<ffi.Void>,
      ffi.Pointer<ffi.Void>,
      ffi.Pointer<ffi.Void>,
    );
typedef _MsgSendVoidPtrNative =
    ffi.Void Function(
      ffi.Pointer<ffi.Void>,
      ffi.Pointer<ffi.Void>,
      ffi.Pointer<ffi.Void>,
    );
typedef _MsgSendVoidPtrDart =
    void Function(
      ffi.Pointer<ffi.Void>,
      ffi.Pointer<ffi.Void>,
      ffi.Pointer<ffi.Void>,
    );
typedef _MsgSendCountNative =
    ffi.Uint64 Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Void>);
typedef _MsgSendCountDart =
    int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Void>);
typedef _MsgSendIndexNative =
    ffi.Pointer<ffi.Void> Function(
      ffi.Pointer<ffi.Void>,
      ffi.Pointer<ffi.Void>,
      ffi.Uint64,
    );
typedef _MsgSendIndexDart =
    ffi.Pointer<ffi.Void> Function(
      ffi.Pointer<ffi.Void>,
      ffi.Pointer<ffi.Void>,
      int,
    );
typedef _MsgSendBoolPtrNative =
    ffi.Bool Function(
      ffi.Pointer<ffi.Void>,
      ffi.Pointer<ffi.Void>,
      ffi.Pointer<ffi.Void>,
    );
typedef _MsgSendBoolPtrDart =
    bool Function(
      ffi.Pointer<ffi.Void>,
      ffi.Pointer<ffi.Void>,
      ffi.Pointer<ffi.Void>,
    );
typedef _CallocNative = ffi.Pointer<ffi.Char> Function(ffi.Size, ffi.Size);
typedef _CallocDart = ffi.Pointer<ffi.Char> Function(int, int);
typedef _FreeNative = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef _FreeDart = void Function(ffi.Pointer<ffi.Void>);
typedef _CGCreateScroll2Native =
    ffi.Pointer<ffi.Void> Function(
      ffi.Pointer<ffi.Void>,
      ffi.Uint32,
      ffi.Uint32,
      ffi.Int32,
      ffi.Int32,
      ffi.Int32,
    );
typedef _CGCreateScroll2Dart =
    ffi.Pointer<ffi.Void> Function(
      ffi.Pointer<ffi.Void>,
      int,
      int,
      int,
      int,
      int,
    );
typedef _CGSetIntFieldNative =
    ffi.Void Function(ffi.Pointer<ffi.Void>, ffi.Uint32, ffi.Int64);
typedef _CGSetIntFieldDart = void Function(ffi.Pointer<ffi.Void>, int, int);
typedef _CFReleaseNative = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef _CFReleaseDart = void Function(ffi.Pointer<ffi.Void>);
typedef _CFStrMakeNative =
    ffi.Pointer<ffi.Void> Function(
      ffi.Pointer<ffi.Void>,
      ffi.Pointer<ffi.Char>,
      ffi.Uint32,
    );
typedef _CFStrMakeDart =
    ffi.Pointer<ffi.Void> Function(
      ffi.Pointer<ffi.Void>,
      ffi.Pointer<ffi.Char>,
      int,
    );
typedef _CFRunLoopGetCurrentNative = ffi.Pointer<ffi.Void> Function();
typedef _CFRunLoopGetCurrentDart = ffi.Pointer<ffi.Void> Function();
typedef _CFAbsoluteTimeGetCurrentNative = ffi.Double Function();
typedef _CFAbsoluteTimeGetCurrentDart = double Function();
typedef _CFTimerCallBackNative =
    ffi.Void Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Void>);
typedef _CFRunLoopTimerCreateNative =
    ffi.Pointer<ffi.Void> Function(
      ffi.Pointer<ffi.Void>,
      ffi.Double,
      ffi.Double,
      ffi.Uint64,
      ffi.Int64,
      ffi.Pointer<ffi.NativeFunction<_CFTimerCallBackNative>>,
      ffi.Pointer<ffi.Void>,
    );
typedef _CFRunLoopTimerCreateDart =
    ffi.Pointer<ffi.Void> Function(
      ffi.Pointer<ffi.Void>,
      double,
      double,
      int,
      int,
      ffi.Pointer<ffi.NativeFunction<_CFTimerCallBackNative>>,
      ffi.Pointer<ffi.Void>,
    );
typedef _CFRunLoopAddTimerNative =
    ffi.Void Function(
      ffi.Pointer<ffi.Void>,
      ffi.Pointer<ffi.Void>,
      ffi.Pointer<ffi.Void>,
    );
typedef _CFRunLoopAddTimerDart =
    void Function(
      ffi.Pointer<ffi.Void>,
      ffi.Pointer<ffi.Void>,
      ffi.Pointer<ffi.Void>,
    );
typedef _CFRunLoopRunInModeNative =
    ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Double, ffi.Uint8);
typedef _CFRunLoopRunInModeDart =
    int Function(ffi.Pointer<ffi.Void>, double, int);
typedef _CFRunLoopStopNative = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef _CFRunLoopStopDart = void Function(ffi.Pointer<ffi.Void>);

/// Synthesizes real AppKit `NSEvent` continuous trackpad scroll events along
/// the exact crash responder chain (`FlutterView` -> `FlutterViewWrapper` ->
/// `FlutterViewController`) without a prior `NSEventPhaseBegan`:
/// 1. Orphan `kCGScrollPhaseChanged` (`NSEventPhaseChanged`)
/// 2. Orphan `kCGScrollPhaseEnded` (`NSEventPhaseEnded` — triggers
///    `FlutterViewController.mm:665` `NSAssert` when unguarded)
/// 3. Complete `Began` -> `Changed` -> `Ended` valid trackpad scroll sequence
///    followed by another orphan `Ended` to verify shadow state reset.
int _exerciseMacOSOrphanTrackpadScrollPhases() {
  final objc = ffi.DynamicLibrary.open('/usr/lib/libobjc.A.dylib');
  final cg = ffi.DynamicLibrary.open(
    '/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics',
  );
  final cf = ffi.DynamicLibrary.open(
    '/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation',
  );
  final proc = ffi.DynamicLibrary.process();

  final callocFn = proc.lookupFunction<_CallocNative, _CallocDart>('calloc');
  final freeFn = proc.lookupFunction<_FreeNative, _FreeDart>('free');
  final getClass = objc.lookupFunction<_ObjcGetClassNative, _ObjcGetClassDart>(
    'objc_getClass',
  );
  final selReg = objc
      .lookupFunction<_SelRegisterNameNative, _SelRegisterNameDart>(
        'sel_registerName',
      );
  final msgSendAddr = objc.lookup<ffi.Void>('objc_msgSend').address;
  final msg0 = ffi.Pointer<ffi.NativeFunction<_MsgSend0Native>>.fromAddress(
    msgSendAddr,
  ).asFunction<_MsgSend0Dart>();
  final msgPtr = ffi.Pointer<ffi.NativeFunction<_MsgSendPtrNative>>.fromAddress(
    msgSendAddr,
  ).asFunction<_MsgSendPtrDart>();
  final msgVoidPtr =
      ffi.Pointer<ffi.NativeFunction<_MsgSendVoidPtrNative>>.fromAddress(
        msgSendAddr,
      ).asFunction<_MsgSendVoidPtrDart>();
  final msgCount =
      ffi.Pointer<ffi.NativeFunction<_MsgSendCountNative>>.fromAddress(
        msgSendAddr,
      ).asFunction<_MsgSendCountDart>();
  final msgIndex =
      ffi.Pointer<ffi.NativeFunction<_MsgSendIndexNative>>.fromAddress(
        msgSendAddr,
      ).asFunction<_MsgSendIndexDart>();
  final msgBoolPtr =
      ffi.Pointer<ffi.NativeFunction<_MsgSendBoolPtrNative>>.fromAddress(
        msgSendAddr,
      ).asFunction<_MsgSendBoolPtrDart>();

  final cgCreateScroll2 = cg
      .lookupFunction<_CGCreateScroll2Native, _CGCreateScroll2Dart>(
        'CGEventCreateScrollWheelEvent2',
      );
  final cgSetIntField = cg
      .lookupFunction<_CGSetIntFieldNative, _CGSetIntFieldDart>(
        'CGEventSetIntegerValueField',
      );
  final cfRelease = cf.lookupFunction<_CFReleaseNative, _CFReleaseDart>(
    'CFRelease',
  );
  final cfStrCreate = cf.lookupFunction<_CFStrMakeNative, _CFStrMakeDart>(
    'CFStringCreateWithCString',
  );
  final cfRunLoopGetCurrent = cf
      .lookupFunction<_CFRunLoopGetCurrentNative, _CFRunLoopGetCurrentDart>(
        'CFRunLoopGetCurrent',
      );
  final cfAbsTime = cf
      .lookupFunction<
        _CFAbsoluteTimeGetCurrentNative,
        _CFAbsoluteTimeGetCurrentDart
      >('CFAbsoluteTimeGetCurrent');
  final cfTimerCreate = cf
      .lookupFunction<_CFRunLoopTimerCreateNative, _CFRunLoopTimerCreateDart>(
        'CFRunLoopTimerCreate',
      );
  final cfAddTimer = cf
      .lookupFunction<_CFRunLoopAddTimerNative, _CFRunLoopAddTimerDart>(
        'CFRunLoopAddTimer',
      );
  final cfRunInMode = cf
      .lookupFunction<_CFRunLoopRunInModeNative, _CFRunLoopRunInModeDart>(
        'CFRunLoopRunInMode',
      );
  final cfRunLoopStop = cf
      .lookupFunction<_CFRunLoopStopNative, _CFRunLoopStopDart>(
        'CFRunLoopStop',
      );

  T withCStr<T>(String s, T Function(ffi.Pointer<ffi.Char>) body) {
    final units = s.codeUnits;
    final buf = callocFn(units.length + 1, 1);
    for (var i = 0; i < units.length; i++) {
      (buf + i).cast<ffi.Uint8>().value = units[i];
    }
    try {
      return body(buf);
    } finally {
      freeFn(buf.cast());
    }
  }

  ffi.Pointer<ffi.Void> cls(String name) => withCStr(name, getClass);
  ffi.Pointer<ffi.Void> sel(String name) => withCStr(name, selReg);

  final nsAppClass = cls('NSApplication');
  final fvcClass = cls('FlutterViewController');
  final nsEventClass = cls('NSEvent');
  if (nsAppClass == ffi.nullptr ||
      fvcClass == ffi.nullptr ||
      nsEventClass == ffi.nullptr) {
    return 0;
  }

  final sharedApp = msg0(nsAppClass, sel('sharedApplication'));
  final windows = msg0(sharedApp, sel('windows'));
  final winCount = msgCount(windows, sel('count'));
  final selContentVC = sel('contentViewController');
  final selIsKindOf = sel('isKindOfClass:');
  final selView = sel('view');
  final selSubviews = sel('subviews');
  final selObjectAtIndex = sel('objectAtIndex:');
  final selScrollWheel = sel('scrollWheel:');
  final selEventWithCG = sel('eventWithCGEvent:');

  var flutterView = ffi.Pointer<ffi.Void>.fromAddress(0);
  for (var i = 0; i < winCount; i++) {
    final win = msgIndex(windows, selObjectAtIndex, i);
    final vc = msg0(win, selContentVC);
    if (vc != ffi.nullptr && msgBoolPtr(vc, selIsKindOf, fvcClass)) {
      final wrapper = msg0(vc, selView);
      final subs = msg0(wrapper, selSubviews);
      if (subs != ffi.nullptr && msgCount(subs, sel('count')) > 0) {
        flutterView = msgIndex(subs, selObjectAtIndex, 0);
        break;
      }
    }
  }
  if (flutterView == ffi.nullptr) {
    return 0;
  }

  void sendScrollPhase(int cgScrollPhase, {int dy = -4, int dx = 0}) {
    // kCGScrollEventUnitPixel = 0, wheelCount = 2
    final cgEv = cgCreateScroll2(ffi.nullptr, 0, 2, dy, dx, 0);
    if (cgEv == ffi.nullptr) {
      return;
    }
    try {
      // kCGScrollWheelEventIsContinuous = 88, kCGScrollWheelEventScrollPhase = 99
      cgSetIntField(cgEv, 88, 1);
      cgSetIntField(cgEv, 99, cgScrollPhase);
      final nsEv = msgPtr(nsEventClass, selEventWithCG, cgEv);
      if (nsEv != ffi.nullptr) {
        msgVoidPtr(flutterView, selScrollWheel, nsEv);
      }
    } finally {
      cfRelease(cgEv);
    }
  }

  // kCGScrollPhaseBegan = 1, Changed = 2, Ended = 4, Cancelled = 8, MayBegin = 128
  // 1) Orphan Changed + Ended (exact NSMenuTrackingSession / WKWebView boundary crash).
  sendScrollPhase(2);
  sendScrollPhase(4);
  // 2) Valid full gesture Began -> Changed -> Ended on FlutterView.
  sendScrollPhase(1);
  sendScrollPhase(2);
  sendScrollPhase(4);
  // 3) Second orphan Ended after valid gesture reset to prove shadow state also reset.
  sendScrollPhase(4);
  // 4) MayBegin -> Cancelled -> orphan Ended.
  sendScrollPhase(128);
  sendScrollPhase(8);
  sendScrollPhase(4);

  // 5) Simulate modal NSMenu tracking (RunLoop.current.currentMode == .eventTracking):
  //    Began sent inside NSEventTrackingRunLoopMode is suppressed, and a subsequent
  //    Ended outside menu tracking must also be suppressed without crashing.
  var menuModeFired = false;
  final currentRl = cfRunLoopGetCurrent();
  final timerCb = ffi.NativeCallable<_CFTimerCallBackNative>.isolateLocal((
    ffi.Pointer<ffi.Void> _,
    ffi.Pointer<ffi.Void> __,
  ) {
    menuModeFired = true;
    sendScrollPhase(1);
    sendScrollPhase(2);
    cfRunLoopStop(currentRl);
  });
  try {
    // kCFStringEncodingUTF8 = 0x08000100
    final modeStr = withCStr(
      'NSEventTrackingRunLoopMode',
      (ffi.Pointer<ffi.Char> p) => cfStrCreate(ffi.nullptr, p, 0x08000100),
    );
    if (modeStr != ffi.nullptr) {
      try {
        final timer = cfTimerCreate(
          ffi.nullptr,
          cfAbsTime() - 1.0,
          0,
          0,
          0,
          timerCb.nativeFunction,
          ffi.nullptr,
        );
        if (timer != ffi.nullptr) {
          try {
            cfAddTimer(currentRl, timer, modeStr);
            cfRunInMode(modeStr, 0.25, 0);
          } finally {
            cfRelease(timer);
          }
        }
      } finally {
        cfRelease(modeStr);
      }
    }
  } finally {
    timerCb.close();
  }
  if (!menuModeFired) {
    return 0;
  }
  // Finger lift arriving right after NSMenuTrackingSession exits:
  sendScrollPhase(4);
  return 12;
}
