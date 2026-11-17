import 'package:flutter/widgets.dart';
import 'package:webview_core/webview_core.dart';

/// Ring buffer of diagnostic lines shown on the Diagnostics tab.
class EventLog extends ChangeNotifier {
  /// Maximum number of retained lines.
  static const int capacity = 300;

  final List<String> _lines = <String>[];

  /// Most recent lines, oldest first.
  List<String> get lines => List<String>.unmodifiable(_lines);

  /// Appends [message] with a wall-clock prefix.
  void add(String message) {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    _lines.add(
      '${two(now.hour)}:${two(now.minute)}:${two(now.second)}  $message',
    );
    if (_lines.length > capacity) {
      _lines.removeRange(0, _lines.length - capacity);
    }
    notifyListeners();
  }

  /// Removes every retained line.
  void clear() {
    _lines.clear();
    notifyListeners();
  }
}

/// Colors shared by every demo tab (light and dark variants).
class DemoPalette {
  /// Creates the palette for the requested brightness.
  const DemoPalette({required this.dark});

  /// Whether the dark variant is active.
  final bool dark;

  /// Window background.
  Color get background =>
      dark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9);

  /// Bars and cards.
  Color get surface => dark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);

  /// Borders and dividers.
  Color get border => dark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

  /// Primary text.
  Color get text => dark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

  /// Secondary text.
  Color get muted => dark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

  /// Accent color.
  Color get accent => const Color(0xFF2563EB);

  /// Positive state color.
  Color get ok => const Color(0xFF16A34A);

  /// Negative state color.
  Color get bad => const Color(0xFFDC2626);

  /// Background applied to the embedded web views.
  Color get preview => dark ? const Color(0xFF101418) : const Color(0xFFF4F1EA);
}

/// State shared by all tabs: both web views, the event log, and UI toggles.
class DemoModel {
  /// Creates the model and attaches the lifecycle logger to both controllers.
  DemoModel() {
    _attachLogging(http, 'http');
    _attachLogging(mail, 'mail');
  }

  /// Controller used by the HTTP Client style preview.
  final WebViewController http = WebViewController();

  /// Controller used by the Mail Sender style live preview.
  final WebViewController mail = WebViewController();

  /// Shared diagnostic log.
  final EventLog log = EventLog();

  /// Active tab index (`0` HTTP, `1` Mail, `2` Diagnostics).
  final ValueNotifier<int> tab = ValueNotifier<int>(0);

  /// Whether the dark theme is active.
  final ValueNotifier<bool> dark = ValueNotifier<bool>(true);

  /// Current palette.
  DemoPalette get palette => DemoPalette(dark: dark.value);

  void _attachLogging(WebViewController controller, String name) {
    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (String url) => log.add('[$name] started  $url'),
        onPageFinished: (String url) => log.add('[$name] finished $url'),
        onWebResourceError: (WebResourceError e) =>
            log.add('[$name] error ${e.errorType?.name} ${e.description}'),
      ),
    );
  }

  /// Releases controllers and notifiers.
  void dispose() {
    http.dispose();
    mail.dispose();
    tab.dispose();
    dark.dispose();
    log.dispose();
  }
}
