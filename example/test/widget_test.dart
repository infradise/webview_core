import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_core_example/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.infradise.webview_core');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('example renders three tabs and switches between them', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const WebViewCoreExampleApp());

    expect(find.text('HTTP Preview'), findsOneWidget);
    expect(find.text('Mail Composer'), findsOneWidget);
    expect(find.text('Diagnostics'), findsOneWidget);
    expect(find.text('Load URL'), findsOneWidget);

    await tester.tap(find.text('Mail Composer'));
    await tester.pump();
    expect(find.text('Send (simulate)'), findsOneWidget);
    expect(
      find.textContaining('preview theme code in editor text: NO (clean)'),
      findsOneWidget,
    );

    await tester.tap(find.text('Diagnostics'));
    await tester.pump();
    expect(find.text('Stress ×100 loadHtml'), findsOneWidget);
    expect(find.text('Cycle tabs ×10'), findsOneWidget);

    // Remove the tree and let pending timers (heartbeat, ping) be disposed.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
