import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_haptics.dart';
import '../../core/utils/amount_input.dart';
import '../../core/utils/keyboard.dart';
import '../../core/utils/text_sanitizer.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';

/// Standard bottom sheet chrome (rounded top, drag handle, title, keyboard
/// inset handling). Replaces 10 near-identical hand-built sheets.
class AppBottomSheet {
  AppBottomSheet._();

  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    required WidgetBuilder builder,
  }) {
    // Otherwise the field that was being edited grabs focus back (and raises
    // the keyboard) the moment this sheet closes.
    dismissKeyboard();
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final p = ctx.palette;
        final media = MediaQuery.of(ctx);
        return Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              20 + media.viewPadding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: p.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                if (title != null) ...[
                  const SizedBox(height: 16),
                  Text(title, style: AppText.title(p.ink)),
                ],
                const SizedBox(height: 16),
                Flexible(child: SingleChildScrollView(child: builder(ctx))),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Describes one text field in [showFieldsSheet].
class FieldSpec {
  final String label;
  final String? hint;
  final String initial;
  final bool numeric;
  final bool required;

  /// Maximum number of characters allowed (non-numeric fields). The limit is
  /// always enforced; the live counter only shows when [showCounter] is true.
  final int? maxLength;

  /// Maximum numeric value for a numeric field (defaults to [kMaxAmount] when
  /// null). Values above this are rejected with a specific message.
  final double? maxValue;

  /// Allowed decimal places for a numeric field.
  final int decimals;

  /// Optional custom validator run after the built-in checks; return a
  /// specific message to block submission, or null to accept.
  final String? Function(String)? validator;

  /// Whether to show a live character counter under the field.
  final bool showCounter;

  /// Whether a numeric field accepts negative values (e.g. a balance).
  final bool allowNegative;

  const FieldSpec({
    required this.label,
    this.hint,
    this.initial = '',
    this.numeric = false,
    this.required = false,
    this.maxLength,
    this.maxValue,
    this.decimals = kAmountDecimals,
    this.validator,
    this.showCounter = false,
    this.allowNegative = false,
  });
}

/// Shows a sheet with the given fields and resolves to the trimmed values (in
/// order), or null if dismissed. Controllers are owned and disposed by the
/// sheet, so callers no longer leak `TextEditingController`s.
///
/// Optionally shows an on/off switch under the fields: pass [switchLabel] and a
/// [switchValue] notifier (owned by the caller) and read its value afterwards.
Future<List<String>?> showFieldsSheet(
  BuildContext context, {
  required String title,
  required List<FieldSpec> fields,
  String submitLabel = 'Save',
  String? switchLabel,
  ValueNotifier<bool>? switchValue,
}) {
  return AppBottomSheet.show<List<String>>(
    context,
    title: title,
    builder: (_) => _FieldsForm(
      fields: fields,
      submitLabel: submitLabel,
      switchLabel: switchLabel,
      switchValue: switchValue,
    ),
  );
}

class _FieldsForm extends StatefulWidget {
  final List<FieldSpec> fields;
  final String submitLabel;
  final String? switchLabel;
  final ValueNotifier<bool>? switchValue;

  const _FieldsForm({
    required this.fields,
    required this.submitLabel,
    this.switchLabel,
    this.switchValue,
  });

  @override
  State<_FieldsForm> createState() => _FieldsFormState();
}

class _FieldsFormState extends State<_FieldsForm> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  final Map<int, String> _errors = {};

  @override
  void initState() {
    super.initState();
    _controllers = [
      for (final f in widget.fields) TextEditingController(text: f.initial),
    ];
    _focusNodes = [for (final _ in widget.fields) FocusNode()];
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  /// Validates one field in a fixed order and returns a specific message, or
  /// null when the field is acceptable.
  String? _validateField(int i) {
    final f = widget.fields[i];
    final raw = _controllers[i].text;

    if (f.required && raw.trim().isEmpty) {
      return raw.isEmpty ? 'This field is required.' : 'Enter a value.';
    }

    if (!f.numeric && f.maxLength != null) {
      if (raw.characters.length > f.maxLength!) {
        return 'Maximum ${f.maxLength} characters.';
      }
    }

    if (f.numeric && raw.trim().isNotEmpty) {
      final err = AmountInput.validateAmount(
        raw,
        allowZero: false,
        max: f.maxValue ?? kMaxAmount,
        allowNegative: f.allowNegative,
      );
      if (err != null) return err;
    }

    final custom = f.validator?.call(raw.trim());
    if (custom != null) return custom;

    return null;
  }

  void _submit() {
    for (var i = 0; i < widget.fields.length; i++) {
      final err = _validateField(i);
      if (err != null) {
        setState(() {
          _errors
            ..clear()
            ..[i] = err;
        });
        _focusNodes[i].requestFocus();
        return;
      }
    }
    Navigator.pop(context, [
      for (var i = 0; i < widget.fields.length; i++)
        widget.fields[i].numeric
            ? _controllers[i].text.trim().replaceAll(',', '')
            : TextSanitizer.singleLine(_controllers[i].text),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.fields.length; i++) ...[
          TextField(
            controller: _controllers[i],
            focusNode: _focusNodes[i],
            autofocus: i == 0,
            keyboardType: widget.fields[i].numeric
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            inputFormatters: widget.fields[i].numeric
                ? AmountInput.amountFormatters(
                    decimals: widget.fields[i].decimals,
                    allowNegative: widget.fields[i].allowNegative,
                  )
                : (widget.fields[i].maxLength != null
                      ? [
                          LengthLimitingTextInputFormatter(
                            widget.fields[i].maxLength,
                          ),
                        ]
                      : null),
            maxLength: widget.fields[i].showCounter
                ? widget.fields[i].maxLength
                : null,
            buildCounter: widget.fields[i].showCounter
                ? null
                : (
                    _, {
                    required currentLength,
                    maxLength,
                    required isFocused,
                  }) => null,
            textInputAction: i == widget.fields.length - 1
                ? TextInputAction.done
                : TextInputAction.next,
            // Live validation: re-check this field on every keystroke so the
            // message appears/clears immediately (no need to press Save).
            onChanged: (_) {
              final err = _validateField(i);
              setState(() {
                if (err == null) {
                  _errors.remove(i);
                } else {
                  _errors[i] = err;
                }
              });
            },
            onSubmitted: (_) {
              if (i == widget.fields.length - 1) _submit();
            },
            decoration: InputDecoration(
              labelText: widget.fields[i].label,
              hintText: widget.fields[i].hint,
              errorText: _errors[i],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (widget.switchValue != null)
          ValueListenableBuilder<bool>(
            valueListenable: widget.switchValue!,
            builder: (context, on, _) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(widget.switchLabel ?? ''),
              value: on,
              onChanged: (v) => widget.switchValue!.value = v,
            ),
          ),
        const SizedBox(height: 4),
        ElevatedButton(onPressed: _submit, child: Text(widget.submitLabel)),
      ],
    );
  }
}

/// Confirmation dialog for destructive actions. Resolves to true if the
/// user confirmed.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) async {
  dismissKeyboard();
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: ctx.palette.expense),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  final confirmed = result ?? false;
  if (confirmed) AppHaptics.warning();
  return confirmed;
}
