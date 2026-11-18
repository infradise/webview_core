import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:webview_core/webview_core.dart';

import 'demo_model.dart';
import 'ui.dart';

/// Reproduces Keyscope's `Mail Sender`: a raw HTML editor on the left and a live
/// WebView preview on the right.
///
/// The preview theme (`<style id="keyscope-preview-theme">`) is added **only** to
/// the string handed to `loadHtmlString`. The editor text — the exact payload a
/// real "Send" would transmit — is never modified.
class MailComposerTab extends StatefulWidget {
  /// Creates the tab.
  const MailComposerTab({required this.model, super.key});

  /// Shared demo state.
  final DemoModel model;

  @override
  State<MailComposerTab> createState() => _MailComposerTabState();
}

class _MailComposerTabState extends State<MailComposerTab> {
  static const Duration _debounce = Duration(milliseconds: 80);
  static const String _themeStyleId = 'keyscope-preview-theme';

  final TextEditingController _editor = TextEditingController(
    text:
        '<h2>Keyscope Update</h2>\n'
        '<p>Notice for waitlist subscribers.</p>\n'
        '<div style="background:#ffffff;padding:12px">'
        '<p>White card without an explicit text color.</p></div>',
  );
  final FocusNode _editorFocus = FocusNode(debugLabel: 'mailEditor');
  Timer? _timer;
  late bool _previewDark = widget.model.dark.value;
  double _split = 0.5;
  int _reloads = 0;
  String _lastSent = '';

  WebViewController get _web => widget.model.mail;

  @override
  void initState() {
    super.initState();
    unawaited(_web.setJavaScriptMode(JavaScriptMode.unrestricted));
    _editor.addListener(_onEdited);
    _push();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _editor.removeListener(_onEdited);
    _editor.dispose();
    _editorFocus.dispose();
    super.dispose();
  }

  void _onEdited() {
    _timer?.cancel();
    _timer = Timer(_debounce, _push);
    setState(() {});
  }

  /// Wraps [raw] with preview-only theme CSS. Never applied to the editor text.
  String _decorate(String raw) {
    final palette = DemoPalette(dark: _previewDark);
    String hex(Color c) =>
        '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final style =
        '<style id="$_themeStyleId">'
        ':where(:root){color-scheme:${_previewDark ? 'dark' : 'light'};'
        'background-color:${hex(palette.preview)};color:${hex(palette.text)};}'
        '</style>';
    return '<!DOCTYPE html><html><head><meta charset="utf-8">$style</head>'
        '<body>$raw</body></html>';
  }

  void _push() {
    _reloads++;
    unawaited(_web.setBackgroundColor(DemoPalette(dark: _previewDark).preview));
    unawaited(_web.loadHtmlString(_decorate(_editor.text)));
    widget.model.log.add('[mail] preview reload #$_reloads');
  }

  void _send() {
    _lastSent = _editor.text;
    widget.model.log.add('[mail] simulated send (${_lastSent.length} chars)');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.model.palette;
    final clean = !_editor.text.contains(_themeStyleId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              final right = box.maxWidth * (1 - _split) - 6;
              return Row(
                children: <Widget>[
                  SizedBox(
                    width: box.maxWidth * _split,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          DemoLabel(
                            'HTML Template (sent as-is)',
                            palette: palette,
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: DemoTextInput(
                              controller: _editor,
                              focusNode: _editorFocus,
                              palette: palette,
                              maxLines: null,
                              monospace: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (DragUpdateDetails d) {
                      setState(() {
                        _split = (_split + d.delta.dx / box.maxWidth).clamp(
                          0.2,
                          0.8,
                        );
                      });
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeColumn,
                      child: SizedBox(
                        width: 6,
                        child: ColoredBox(color: palette.border),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: right,
                    child: ColoredBox(
                      color: palette.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                DemoLabel('Live Preview', palette: palette),
                                DemoButton(
                                  label: _previewDark
                                      ? 'Preview: dark'
                                      : 'Preview: light',
                                  palette: palette,
                                  onTap: () {
                                    setState(
                                      () => _previewDark = !_previewDark,
                                    );
                                    _push();
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: WebViewWidget(
                                  key: const ValueKey<String>(
                                    'mail_preview_webview',
                                  ),
                                  controller: _web,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border(top: BorderSide(color: palette.border)),
          ),
          child: Row(
            children: <Widget>[
              DemoButton(
                label: 'Send (simulate)',
                palette: palette,
                onTap: _send,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Outbound payload: ${_lastSent.isEmpty ? '(not sent yet)' : '${_lastSent.length} chars'}'
                  '  •  preview theme code in editor text: ${clean ? 'NO (clean)' : 'YES (BUG)'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: clean ? palette.ok : palette.bad,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
