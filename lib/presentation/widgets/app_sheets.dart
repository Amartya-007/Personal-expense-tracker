import 'package:flutter/material.dart';

import '../../core/theme/app_haptics.dart';
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
                Flexible(
                  child: SingleChildScrollView(child: builder(ctx)),
                ),
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

  const FieldSpec({
    required this.label,
    this.hint,
    this.initial = '',
    this.numeric = false,
    this.required = false,
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
  int? _errorIndex;

  @override
  void initState() {
    super.initState();
    _controllers = [
      for (final f in widget.fields) TextEditingController(text: f.initial),
    ];
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    for (var i = 0; i < widget.fields.length; i++) {
      if (widget.fields[i].required && _controllers[i].text.trim().isEmpty) {
        setState(() => _errorIndex = i);
        return;
      }
    }
    Navigator.pop(context, [for (final c in _controllers) c.text.trim()]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.fields.length; i++) ...[
          TextField(
            controller: _controllers[i],
            autofocus: i == 0,
            keyboardType: widget.fields[i].numeric
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            textInputAction: i == widget.fields.length - 1
                ? TextInputAction.done
                : TextInputAction.next,
            onChanged: (_) {
              if (_errorIndex == i) setState(() => _errorIndex = null);
            },
            onSubmitted: (_) {
              if (i == widget.fields.length - 1) _submit();
            },
            decoration: InputDecoration(
              labelText: widget.fields[i].label,
              hintText: widget.fields[i].hint,
              errorText: _errorIndex == i ? 'This field is required' : null,
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
