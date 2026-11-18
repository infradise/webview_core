import 'package:flutter/widgets.dart';

import 'demo_model.dart';

/// Flat text button used across the demo.
class DemoButton extends StatelessWidget {
  /// Creates a [DemoButton].
  const DemoButton({
    required this.label,
    required this.onTap,
    required this.palette,
    this.active = false,
    super.key,
  });

  /// Button caption.
  final String label;

  /// Tap callback.
  final VoidCallback onTap;

  /// Active palette.
  final DemoPalette palette;

  /// Whether the button is rendered as selected.
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? palette.accent : palette.border,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFFFFFFFF) : palette.text,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Minimal text input built only on `package:flutter/widgets.dart`.
class DemoTextInput extends StatelessWidget {
  /// Creates a [DemoTextInput].
  const DemoTextInput({
    required this.controller,
    required this.focusNode,
    required this.palette,
    this.maxLines = 1,
    this.monospace = false,
    this.onSubmitted,
    super.key,
  });

  /// Backing text controller.
  final TextEditingController controller;

  /// Focus node owned by the caller.
  final FocusNode focusNode;

  /// Active palette.
  final DemoPalette palette;

  /// Line limit (`null` for unlimited multi-line editing).
  final int? maxLines;

  /// Whether to use a monospace font.
  final bool monospace;

  /// Invoked when a single-line field is submitted.
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: EditableText(
        controller: controller,
        focusNode: focusNode,
        maxLines: maxLines,
        expands: maxLines == null,
        keyboardType: maxLines == 1
            ? TextInputType.url
            : TextInputType.multiline,
        style: TextStyle(
          color: palette.text,
          fontSize: 13,
          fontFamily: monospace ? 'Menlo' : null,
        ),
        cursorColor: palette.accent,
        backgroundCursorColor: palette.border,
        selectionColor: palette.accent.withValues(alpha: 0.35),
        onSubmitted: onSubmitted,
      ),
    );
  }
}

/// Section caption.
class DemoLabel extends StatelessWidget {
  /// Creates a [DemoLabel].
  const DemoLabel(this.text, {required this.palette, super.key});

  /// Caption text.
  final String text;

  /// Active palette.
  final DemoPalette palette;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: palette.muted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
