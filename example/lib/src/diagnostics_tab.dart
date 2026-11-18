import 'dart:async';

import 'package:flutter/widgets.dart';

import 'demo_model.dart';
import 'ui.dart';

/// Freeze detector: a UI heartbeat, a native round-trip probe, stress actions,
/// and the shared event log.
class DiagnosticsTab extends StatefulWidget {
  /// Creates the tab.
  const DiagnosticsTab({required this.model, super.key});

  /// Shared demo state.
  final DemoModel model;

  @override
  State<DiagnosticsTab> createState() => _DiagnosticsTabState();
}

class _DiagnosticsTabState extends State<DiagnosticsTab> {
  Timer? _heartbeatTimer;
  Timer? _pingTimer;
  int _ticks = 0;
  String _httpPing = '—';
  String _mailPing = '—';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _heartbeatTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) {
        setState(() => _ticks++);
      }
    });
    _pingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_ping());
    });
    widget.model.log.addListener(_onLog);
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _pingTimer?.cancel();
    widget.model.log.removeListener(_onLog);
    super.dispose();
  }

  void _onLog() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<String> _probe(Future<String?> Function() call) async {
    final watch = Stopwatch()..start();
    try {
      final value = await call().timeout(const Duration(seconds: 2));
      return value == null
          ? 'no result (view not ready)'
          : '${watch.elapsedMilliseconds} ms';
    } on TimeoutException {
      return 'NO RESPONSE (>2s)';
    }
  }

  Future<void> _ping() async {
    final http = await _probe(() => widget.model.http.evaluateJavaScript('1'));
    final mail = await _probe(() => widget.model.mail.evaluateJavaScript('1'));
    if (!mounted) {
      return;
    }
    setState(() {
      _httpPing = http;
      _mailPing = mail;
    });
  }

  Future<void> _stress() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    widget.model.log.add(
      '[diag] stress: 100 rapid loadHtmlString on both views',
    );
    for (var i = 1; i <= 100; i++) {
      final html = '<h1>Stress $i</h1>';
      unawaited(widget.model.http.loadHtmlString(html));
      unawaited(widget.model.mail.loadHtmlString(html));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    widget.model.log.add('[diag] stress done');
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _cycleTabs() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    widget.model.log.add('[diag] cycling HTTP/Mail/Diagnostics tabs x10');
    for (var i = 0; i < 10; i++) {
      for (final next in <int>[0, 1, 2]) {
        widget.model.tab.value = next;
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }
    widget.model.log.add('[diag] tab cycle done');
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  Color _pingColor(DemoPalette palette, String value) =>
      value.contains('NO RESPONSE') ? palette.bad : palette.ok;

  @override
  Widget build(BuildContext context) {
    final palette = widget.model.palette;
    final lines = widget.model.log.lines.reversed.toList(growable: false);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DemoLabel(
            'UI heartbeat (stops if the Flutter UI freezes)',
            palette: palette,
          ),
          const SizedBox(height: 4),
          Text(
            'tick #$_ticks',
            style: TextStyle(color: palette.text, fontSize: 18),
          ),
          const SizedBox(height: 10),
          DemoLabel('Native round trip (evaluateJavaScript)', palette: palette),
          const SizedBox(height: 4),
          Text(
            'HTTP view: $_httpPing',
            style: TextStyle(
              color: _pingColor(palette, _httpPing),
              fontSize: 13,
            ),
          ),
          Text(
            'Mail view: $_mailPing',
            style: TextStyle(
              color: _pingColor(palette, _mailPing),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              DemoButton(
                label: _busy ? 'Running…' : 'Stress ×100 loadHtml',
                palette: palette,
                onTap: () => unawaited(_stress()),
              ),
              DemoButton(
                label: _busy ? 'Running…' : 'Cycle tabs ×10',
                palette: palette,
                onTap: () => unawaited(_cycleTabs()),
              ),
              DemoButton(
                label: 'Ping now',
                palette: palette,
                onTap: () => unawaited(_ping()),
              ),
              DemoButton(
                label: 'Clear log',
                palette: palette,
                onTap: widget.model.log.clear,
              ),
            ],
          ),
          const SizedBox(height: 10),
          DemoLabel('Event log', palette: palette),
          const SizedBox(height: 4),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border.all(color: palette.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ListView.builder(
                itemCount: lines.length,
                itemBuilder: (BuildContext context, int index) => Text(
                  lines[index],
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 11,
                    fontFamily: 'Menlo',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
