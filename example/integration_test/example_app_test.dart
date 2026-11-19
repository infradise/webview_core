import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:webview_core_example/main.dart';

/// Drives the real example application (real native WebViews) through the
/// user flows that previously froze it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, {int ms = 1500}) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Taps `Eval title` until the HTTP preview answers with its page title.
  /// Page load time differs between developer machines and CI runners, and the
  /// status line carries a per-tap counter so a stale answer can never match.
  var evalTaps = 0;
  Future<bool> titleAnswered(WidgetTester tester) async {
    for (var i = 0; i < 60; i++) {
      await tester.tap(find.text('Eval title'));
      evalTaps++;
      await tester.pump(const Duration(milliseconds: 500));
      final answer = find.textContaining(
        'document.title = example.com (sample SSR page) (eval #$evalTaps)',
      );
      if (answer.evaluate().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('example survives tab cycling, typing, and theme toggles', (
    tester,
  ) async {
    await tester.pumpWidget(const WebViewCoreExampleApp());

    // HTTP tab: native JS works after initial load.
    expect(
      await titleAnswered(tester),
      isTrue,
      reason: 'HTTP preview did not load / answer JS',
    );

    // Cycle all tabs repeatedly (hide/show of both native views).
    for (var i = 0; i < 12; i++) {
      await openTab(tester, 'Mail Composer');
      await openTab(tester, 'Diagnostics');
      await openTab(tester, 'HTTP Preview');
    }
    await settle(tester, ms: 800);

    // The HTTP view must still be alive after the cycles.
    await tester.tap(find.text('Scripts: stripped'));
    expect(
      await titleAnswered(tester),
      isTrue,
      reason: 'HTTP preview died after tab cycling',
    );

    // Mail tab: typing + preview theme toggles keep the editor payload clean.
    await openTab(tester, 'Mail Composer');
    await tester.enterText(
      find.byType(EditableText).last,
      '<h1>Typed</h1><p>plain text</p>',
    );
    await settle(tester, ms: 400);
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.textContaining(RegExp('^Preview: (dark|light)\$')));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await settle(tester, ms: 600);
    expect(
      find.textContaining('preview theme code in editor text: NO (clean)'),
      findsOneWidget,
    );
    await tester.tap(find.text('Send (simulate)'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('Outbound payload: 31 chars'), findsOneWidget);

    // Diagnostics: both native views answer the round-trip probe.
    await openTab(tester, 'Diagnostics');
    await tester.tap(find.text('Ping now'));
    await settle(tester, ms: 1200);
    expect(find.textContaining('HTTP view: '), findsOneWidget);
    expect(find.textContaining('NO RESPONSE'), findsNothing);
    expect(find.textContaining('ms'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
  });
}
