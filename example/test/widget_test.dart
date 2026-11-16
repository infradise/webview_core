import 'package:flutter_test/flutter_test.dart';
import 'package:webview_core_example/main.dart';

void main() {
  testWidgets('WebViewCoreExampleApp renders controls and switches tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const WebViewCoreExampleApp());

    expect(find.text('Preview Tab'), findsOneWidget);
    expect(find.text('Inspector Tab (Visibility Check)'), findsOneWidget);
    expect(find.text('Load HTML'), findsOneWidget);
    expect(find.text('Eval JS'), findsOneWidget);
    expect(find.text('Reload'), findsOneWidget);

    await tester.tap(find.text('Inspector Tab (Visibility Check)'));
    await tester.pump();

    expect(find.text('Native Overlay Visibility Verification'), findsOneWidget);
  });
}
