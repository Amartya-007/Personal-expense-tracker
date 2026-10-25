import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/logging/log_entry.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import 'app_sheets.dart';
import 'log_level_badge.dart';
import 'primary_button.dart';

/// Full view of one log entry in a bottom sheet. Long technical text is
/// selectable and scrolls inside its own box.
Future<void> showLogDetailSheet(BuildContext context, AppLogEntry entry) {
  return AppBottomSheet.show<void>(
    context,
    title: 'Log details',
    builder: (ctx) => _LogDetail(entry: entry),
  );
}

class _LogDetail extends StatelessWidget {
  final AppLogEntry entry;

  const _LogDetail({required this.entry});

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: entry.toDiagnosticText()));
    messenger.showSnackBar(const SnackBar(content: Text('Log details copied')));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final when = DateFormat('d MMM yyyy, h:mm:ss a').format(entry.timestamp);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            LogLevelBadge(level: entry.level),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                entry.category.label,
                style: AppText.bodyStrong(p.ink),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(when, style: AppText.caption(p.muted)),
        const SizedBox(height: 14),
        SelectableText(entry.message, style: AppText.body(p.ink)),
        if (_has(entry.details))
          _Section(title: 'Details', text: entry.details!),
        if (_has(entry.error)) _Section(title: 'Error', text: entry.error!),
        if (_has(entry.stackTrace))
          _Section(title: 'Stack trace', text: entry.stackTrace!, scroll: true),
        const SizedBox(height: 18),
        PrimaryButton(
          label: 'Copy details',
          icon: Icons.copy_rounded,
          onPressed: () => _copy(context),
        ),
      ],
    );
  }

  static bool _has(String? s) => s != null && s.isNotEmpty;
}

class _Section extends StatelessWidget {
  final String title;
  final String text;

  /// Long, wide text (stack traces): fixed height box that scrolls both ways.
  final bool scroll;

  const _Section({
    required this.title,
    required this.text,
    this.scroll = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final body = SelectableText(
      text,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        height: 1.45,
        color: p.ink,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.overline(p.muted)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.surface2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.border),
            ),
            child: scroll
                ? ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: body,
                      ),
                    ),
                  )
                : body,
          ),
        ],
      ),
    );
  }
}
