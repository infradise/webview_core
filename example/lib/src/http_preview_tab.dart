import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:webview_core/webview_core.dart';

import 'demo_model.dart';
import 'ui.dart';

/// Reproduces Keyscope's `HTTP Client > Preview`: an HTTP response body rendered
/// with its request URL as `baseUrl`, optionally with `<script>` tags removed.
class HttpPreviewTab extends StatefulWidget {
  /// Creates the tab.
  const HttpPreviewTab({required this.model, super.key});

  /// Shared demo state.
  final DemoModel model;

  @override
  State<HttpPreviewTab> createState() => _HttpPreviewTabState();
}

class _HttpPreviewTabState extends State<HttpPreviewTab> {
  static const String _kSampleBase = 'https://keyscope.dev/docs/';

  final TextEditingController _url = TextEditingController(
    text: 'https://keyscope.dev',
  );
  final FocusNode _urlFocus = FocusNode(debugLabel: 'httpUrl');
  bool _stripScripts = true;
  int _progress = 0;
  String _status = 'Ready';
  String _title = '';
  int _evalCount = 0;

  WebViewController get _web => widget.model.http;

  @override
  void initState() {
    super.initState();
    unawaited(_web.setJavaScriptMode(JavaScriptMode.unrestricted));
    unawaited(_web.setBackgroundColor(widget.model.palette.preview));
    unawaited(
      _web.setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int p) {
            if (mounted) {
              setState(() => _progress = p);
            }
          },
          onPageStarted: (String url) {
            widget.model.log.add('[http] started  $url');
            if (mounted) {
              setState(() => _status = 'Loading $url');
            }
          },
          onPageFinished: (String url) {
            widget.model.log.add('[http] finished $url');
            unawaited(_refreshTitle());
            if (mounted) {
              setState(() => _status = 'Loaded $url');
            }
          },
          onWebResourceError: (WebResourceError e) {
            widget.model.log.add('[http] error ${e.description}');
            if (mounted) {
              setState(() => _status = 'Error: ${e.description}');
            }
          },
        ),
      ),
    );
    unawaited(_loadSample());
  }

  @override
  void dispose() {
    _url.dispose();
    _urlFocus.dispose();
    super.dispose();
  }

  Future<void> _refreshTitle() async {
    final title = await _web.getTitle();
    if (mounted) {
      setState(() => _title = title ?? '');
    }
  }

  static final RegExp _scriptTag = RegExp(
    r'<script\b[^>]*>[\s\S]*?</script\s*>',
    caseSensitive: false,
  );

  String _prepare(String html) =>
      _stripScripts ? html.replaceAll(_scriptTag, '') : html;

  Future<void> _loadSample() {
    return _web.loadHtmlString(_prepare(_sampleHtml), baseUrl: _kSampleBase);
  }

  Future<void> _loadUrl() {
    final uri = Uri.tryParse(_url.text.trim());
    if (uri == null || !uri.hasScheme) {
      setState(() => _status = 'Enter a full http(s) URL');
      return Future<void>.value();
    }
    return _web.loadRequest(uri);
  }

  Future<void> _evalTitle() async {
    final value = await _web.evaluateJavaScript('document.title');
    final count = ++_evalCount;
    widget.model.log.add('[http] document.title = ${value ?? '(null)'}');
    if (mounted) {
      setState(
        () => _status = 'document.title = ${value ?? '(null)'} (eval #$count)',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.model.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: DemoTextInput(
                  controller: _url,
                  focusNode: _urlFocus,
                  palette: palette,
                  onSubmitted: (_) => unawaited(_loadUrl()),
                ),
              ),
              const SizedBox(width: 8),
              DemoButton(
                label: 'Load URL',
                palette: palette,
                onTap: () => unawaited(_loadUrl()),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              DemoButton(
                label: 'Load sample HTML',
                palette: palette,
                onTap: () => unawaited(_loadSample()),
              ),
              DemoButton(
                label: _stripScripts ? 'Scripts: stripped' : 'Scripts: kept',
                palette: palette,
                active: _stripScripts,
                onTap: () {
                  setState(() => _stripScripts = !_stripScripts);
                  unawaited(_loadSample());
                },
              ),
              DemoButton(
                label: 'Back',
                palette: palette,
                onTap: () => unawaited(_web.goBack()),
              ),
              DemoButton(
                label: 'Forward',
                palette: palette,
                onTap: () => unawaited(_web.goForward()),
              ),
              DemoButton(
                label: 'Reload',
                palette: palette,
                onTap: () => unawaited(_web.reload()),
              ),
              DemoButton(
                label: 'Eval title',
                palette: palette,
                onTap: () => unawaited(_evalTitle()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: palette.border),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: WebViewWidget(
                key: const ValueKey<String>('http_preview_webview'),
                controller: _web,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            '$_status  ($_progress%)${_title.isEmpty ? '' : '  •  $_title'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

const String _sampleHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>keyscope.dev (sample SSR page)</title>
  <link rel="icon" href="/favicon.ico">
  <style>
    body { margin: 0; font-family: -apple-system, "Segoe UI", sans-serif; background: #fff; }
    header { display: flex; align-items: center; justify-content: space-between;
             padding: 12px 20px; border-bottom: 1px solid #e2e8f0; }
    nav a { margin-right: 14px; color: #2563eb; text-decoration: none; }
    #menu { display: none; padding: 12px 20px; background: #f1f5f9; }
    main { padding: 20px; }
    button { background: #2563eb; color: #fff; border: 0; border-radius: 6px; padding: 8px 14px; }
  </style>
</head>
<body>
  <header>
    <strong>Keyscope</strong>
    <nav>
      <a href="#features">Features</a>
      <a href="https://keyscope.dev/pricing" target="_blank">Pricing (target=_blank)</a>
    </nav>
    <button id="burger" onclick="document.getElementById('menu').style.display='block'">Menu</button>
  </header>
  <div id="menu">Mobile menu (needs JavaScript)</div>
  <main>
    <h2 id="features">Features</h2>
    <p>Static SSR-style document. Links work without JavaScript; the Menu button
       only works when scripts are kept (toggle "Scripts" above).</p>
    <p><a href="#features">Anchor link</a> &middot;
       <a href="https://keyscope.dev/docs" target="_blank">Docs (opens in place)</a></p>
  </main>
</body>
</html>
''';
