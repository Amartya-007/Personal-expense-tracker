import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/permissions/permission_service.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import 'app_card.dart';
import 'app_sheets.dart';
import 'primary_button.dart';

/// The adb command that grants SMS access directly (needs USB debugging and a
/// computer). Handy for a personal device where the in-app request is blocked.
const String _adbCommand =
    'adb shell pm grant com.MyKhata.mykhata android.permission.READ_SMS && '
    'adb shell pm grant com.MyKhata.mykhata android.permission.RECEIVE_SMS';

/// Explains how to unblock SMS access on Android and offers the shortcuts.
///
/// Android 13+ keeps the SMS permission switched off ("Restricted settings")
/// for apps installed from an APK instead of an app store, and Google Play
/// only allows SMS access for default SMS apps. [onPaste] lets the user fall
/// back to pasting messages, which needs no permission.
Future<void> showSmsPermissionHelp(
  BuildContext context, {
  VoidCallback? onPaste,
}) {
  return AppBottomSheet.show<void>(
    context,
    title: 'SMS access is blocked',
    builder: (ctx) {
      final p = ctx.palette;

      Widget step(String number, String text) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.surface2,
                    shape: BoxShape.circle,
                  ),
                  child: Text(number, style: AppText.section(p.primary)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(text, style: AppText.caption(p.ink).copyWith(fontSize: 13)),
                ),
              ],
            ),
          );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'On a phone that installed MyKhata from an APK, Android keeps SMS access switched off for safety. Since this is your own app, you can allow it:',
            style: AppText.caption(p.muted).copyWith(fontSize: 13),
          ),
          const SizedBox(height: 14),
          step('1', 'Tap “Open app settings” below (Settings → Apps → MyKhata).'),
          step(
            '2',
            'Tap the ⋮ menu at the top right and choose “Allow restricted settings”. It only appears after you have tried to enable SMS once.',
          ),
          step('3', 'Go to Permissions → SMS → Allow, then come back here.'),
          const SizedBox(height: 4),
          Text(
            'Or from a computer with USB debugging:',
            style: AppText.caption(p.muted),
          ),
          const SizedBox(height: 6),
          AppCard(
            shadow: false,
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                const Expanded(
                  child: SelectableText(
                    _adbCommand,
                    style: TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy command',
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(const ClipboardData(text: _adbCommand));
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Command copied')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Open app settings',
            icon: Icons.settings_rounded,
            onPressed: () {
              Navigator.pop(ctx);
              PermissionService.openSettings();
            },
          ),
          if (onPaste != null) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                onPaste();
              },
              style: TextButton.styleFrom(foregroundColor: p.muted),
              child: const Text('Paste messages instead (no permission needed)'),
            ),
          ],
        ],
      );
    },
  );
}
