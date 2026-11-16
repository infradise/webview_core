import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:webview_core/webview_core.dart';

/// Launches the `webview_core` interactive example application.
void main() {
  runApp(const WebViewCoreExampleApp());
}

/// Cross-platform example application built exclusively with
/// `package:flutter/widgets.dart`.
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

/// Interactive testbed screen demonstrating HTML loading, dark/light theme
/// background synchronization, JavaScript channels, and `IndexedStack`
/// visibility management.
class WebViewCoreHomePage extends StatefulWidget {
  /// Creates the [WebViewCoreHomePage].
  const WebViewCoreHomePage({super.key});

  @override
  State<WebViewCoreHomePage> createState() => _WebViewCoreHomePageState();
}

class _WebViewCoreHomePageState extends State<WebViewCoreHomePage> {
  late final WebViewController _controller;
  bool _isDarkMode = true;
  int _activeTab = 0;
  int _progress = 0;
  String _statusText = 'Ready';
  String _lastChannelMessage = 'No JavaScript channel message yet.';

  static String _buildSampleHtml({required bool dark}) {
    final bg = dark ? '#0F172A' : '#F8FAFC';
    final card = dark ? '#1E293B' : '#FFFFFF';
    final text = dark ? '#F1F5F9' : '#0F172A';
    final muted = dark ? '#94A3B8' : '#475569';
    final border = dark ? '#334155' : '#E2E8F0';
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>webview_core Preview</title>
  <style>
    body {
      margin: 0;
      padding: 24px;
      background-color: $bg;
      color: $text;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    }
    .card {
      background: $card;
      border: 1px solid $border;
      border-radius: 10px;
      padding: 20px;
      max-width: 680px;
    }
    h2 { margin: 0 0 8px 0; font-size: 20px; }
    p { margin: 0 0 16px 0; color: $muted; line-height: 1.5; }
    button {
      background: #2563EB;
      color: #FFFFFF;
      border: 0;
      border-radius: 6px;
      padding: 8px 14px;
      font-size: 13px;
      cursor: pointer;
    }
  </style>
</head>
<body>
  <div class="card">
    <h2>webview_core Native &amp; Wasm Preview</h2>
    <p>Theme mode: <strong>${dark ? 'Dark' : 'Light'}</strong>. Click below to post a message to Flutter via the registered JavaScript channel.</p>
    <button onclick="if (window.AppBridge) { window.AppBridge.postMessage('Ping from JS (' + new Date().toISOString() + ')'); }">
      Send Message to Flutter
    </button>
  </div>
</body>
</html>
''';
  }

  Color get _backdropColor =>
      _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    unawaited(_controller.setJavaScriptMode(JavaScriptMode.unrestricted));
    unawaited(_controller.setBackgroundColor(_backdropColor));
    unawaited(
      _controller.addJavaScriptChannel(
        'AppBridge',
        onMessageReceived: (JavaScriptMessage msg) {
          if (!mounted) {
            return;
          }
          setState(() {
            _lastChannelMessage = msg.message;
          });
        },
      ),
    );
    unawaited(
      _controller.setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int p) {
            if (mounted) {
              setState(() => _progress = p);
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() => _statusText = 'Loading: $url');
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() => _statusText = 'Loaded: $url');
            }
          },
          onWebResourceError: (WebResourceError err) {
            if (mounted) {
              setState(() => _statusText = 'Error: ${err.description}');
            }
          },
        ),
      ),
    );
    unawaited(_controller.loadHtmlString(_buildSampleHtml(dark: _isDarkMode)));
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _toggleTheme() async {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    await _controller.setBackgroundColor(_backdropColor);
    await _controller.loadHtmlString(_buildSampleHtml(dark: _isDarkMode));
  }

  Future<void> _runTitleQuery() async {
    final title = await _controller.evaluateJavaScript('document.title');
    if (!mounted) {
      return;
    }
    setState(() {
      _lastChannelMessage = 'JS Result: ${title ?? '(null)'}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final surfaceBg = _isDarkMode
        ? const Color(0xFF0B1120)
        : const Color(0xFFF1F5F9);
    final barBg = _isDarkMode
        ? const Color(0xFF1E293B)
        : const Color(0xFFFFFFFF);
    final borderColor = _isDarkMode
        ? const Color(0xFF334155)
        : const Color(0xFFCBD5E1);
    final textColor = _isDarkMode
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final subTextColor = _isDarkMode
        ? const Color(0xFF94A3B8)
        : const Color(0xFF475569);

    return ColoredBox(
      color: surfaceBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: barBg,
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  _ActionButton(
                    label: 'Preview Tab',
                    active: _activeTab == 0,
                    onTap: () => setState(() => _activeTab = 0),
                  ),
                  _ActionButton(
                    label: 'Inspector Tab (Visibility Check)',
                    active: _activeTab == 1,
                    onTap: () => setState(() => _activeTab = 1),
                  ),
                  _ActionButton(
                    label: _isDarkMode ? 'Switch Light' : 'Switch Dark',
                    onTap: () => unawaited(_toggleTheme()),
                  ),
                  _ActionButton(
                    label: 'Load HTML',
                    onTap: () => unawaited(
                      _controller.loadHtmlString(
                        _buildSampleHtml(dark: _isDarkMode),
                      ),
                    ),
                  ),
                  _ActionButton(
                    label: 'Eval JS',
                    onTap: () => unawaited(_runTitleQuery()),
                  ),
                  _ActionButton(
                    label: 'Reload',
                    onTap: () => unawaited(_controller.reload()),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: IndexedStack(
                  index: _activeTab,
                  children: <Widget>[
                    Container(
                      decoration: BoxDecoration(
                        color: _backdropColor,
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: WebViewWidget(
                        key: const ValueKey<String>('example_webview'),
                        controller: _controller,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: barBg,
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Native Overlay Visibility Verification',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'While this tab is active, standard IndexedStack '
                            'visibility tracking automatically hides background '
                            'native WebView surfaces with zero ghosting and '
                            'zero click interception.',
                            style: TextStyle(color: subTextColor, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: barBg,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '$_statusText  ($_progress%)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _lastChannelMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(color: textColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bg = active ? const Color(0xFF2563EB) : const Color(0xFF334155);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
