import 'package:flutter/widgets.dart';

import 'src/demo_model.dart';
import 'src/diagnostics_tab.dart';
import 'src/http_preview_tab.dart';
import 'src/mail_composer_tab.dart';
import 'src/ui.dart';

/// Launches the `webview_core` interactive example application.
void main() {
  runApp(const WebViewCoreExampleApp());
}

/// Example application built exclusively with `package:flutter/widgets.dart`.
///
/// Demonstrates an HTTP response preview and a live HTML email preview kept
/// mounted inside an `IndexedStack`, alongside a Diagnostics tab to exercise
/// hide/show, resize, and reload lifecycles.
class WebViewCoreExampleApp extends StatelessWidget {
  /// Creates the example application.
  const WebViewCoreExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'webview_core Testbed',
      color: const Color(0xFF2563EB),
      debugShowCheckedModeBanner: false,
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
        return PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (BuildContext context, _, _) => builder(context),
        );
      },
      home: const WebViewCoreHomePage(),
    );
  }
}

/// Tabbed home screen hosting the HTTP, Mail, and Diagnostics tabs.
class WebViewCoreHomePage extends StatefulWidget {
  /// Creates the [WebViewCoreHomePage].
  const WebViewCoreHomePage({super.key});

  @override
  State<WebViewCoreHomePage> createState() => _WebViewCoreHomePageState();
}

class _WebViewCoreHomePageState extends State<WebViewCoreHomePage> {
  final DemoModel _model = DemoModel();

  @override
  void initState() {
    super.initState();
    _model.tab.addListener(_rebuild);
    _model.dark.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _model.tab.removeListener(_rebuild);
    _model.dark.removeListener(_rebuild);
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _model.palette;
    const titles = <String>['HTTP Preview', 'Mail Composer', 'Diagnostics'];
    return ColoredBox(
      color: palette.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border(bottom: BorderSide(color: palette.border)),
              ),
              child: Row(
                children: <Widget>[
                  for (var i = 0; i < titles.length; i++) ...<Widget>[
                    DemoButton(
                      label: titles[i],
                      palette: palette,
                      active: _model.tab.value == i,
                      onTap: () => _model.tab.value = i,
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Spacer(),
                  DemoButton(
                    label: _model.dark.value ? 'Dark' : 'Light',
                    palette: palette,
                    onTap: () => _model.dark.value = !_model.dark.value,
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _model.tab.value,
                children: <Widget>[
                  HttpPreviewTab(model: _model),
                  MailComposerTab(model: _model),
                  DiagnosticsTab(model: _model),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
