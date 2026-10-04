import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_providers.dart';
import '../../providers/sms_review_providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_sheets.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/list_widgets.dart';
import '../../widgets/pressable.dart';
import '../../widgets/section_header.dart';
import '../sms_review/sms_review_screen.dart';
import 'accounts_management_screen.dart';
import 'backup_restore_screen.dart';
import 'categories_management_screen.dart';
import 'receipt_gallery_screen.dart';
import 'recently_deleted_screen.dart';
import 'recurring_payments_screen.dart';
import 'tags_management_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final values = await showFieldsSheet(
      context,
      title: 'Your name',
      submitLabel: 'Save',
      fields: [
        FieldSpec(
          label: 'Name',
          hint: 'What should we call you?',
          initial: current,
          required: true,
        ),
      ],
    );
    if (values == null) return;
    await ref.read(userNameProvider.notifier).setUserName(values[0]);
  }

  /// Turning a feature on asks for the OS permission first; if it is refused
  /// the switch stays off and the user is told why.
  Future<void> _togglePermissionPref({
    required BuildContext context,
    required bool value,
    required BoolPrefNotifier notifier,
    required Future<bool> Function() requestPermission,
    required String deniedMessage,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    if (value) {
      final granted = await requestPermission();
      if (!granted) {
        await notifier.set(false);
        messenger.showSnackBar(SnackBar(content: Text(deniedMessage)));
        return;
      }
    }
    await notifier.set(value);
  }

  Future<void> _toggleBiometrics(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final success =
        await ref.read(authProvider.notifier).toggleBiometrics(value);
    if (!success && value) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to enable biometrics. Make sure a fingerprint, face or screen lock is set up in Android Settings.',
          ),
        ),
      );
    }
  }

  void _showAppearanceSheet(BuildContext context) {
    AppBottomSheet.show<void>(
      context,
      title: 'Appearance',
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          // Watched inside the sheet so the selection updates live. (This used
          // to call ref.watch from a tap callback, which Riverpod rejects.)
          final mode = ref.watch(themeModeProvider);
          return SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_rounded),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_rounded),
                label: Text('Dark'),
              ),
            ],
            selected: {mode == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light},
            onSelectionChanged: (s) =>
                ref.read(themeModeProvider.notifier).setThemeMode(s.first),
          );
        },
      ),
    );
  }

  void _showAbout(BuildContext context) {
    AppBottomSheet.show<void>(
      context,
      builder: (ctx) {
        final p = ctx.palette;
        return Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                gradient: p.heroGradient,
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: const Text('📒', style: TextStyle(fontSize: 36)),
            ),
            const SizedBox(height: 14),
            Text('MyKhata', style: AppText.display(p.ink)),
            const SizedBox(height: 6),
            Text(
              'Version 1.0 · Offline · No ads · No login',
              style: AppText.caption(p.muted),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final auth = ref.watch(authProvider);
    final name = ref.watch(userNameProvider);
    final smsOn = ref.watch(autoSmsDetectionProvider);
    final locationOn = ref.watch(autoLocationCaptureProvider);
    final themeMode = ref.watch(themeModeProvider);
    final waiting = ref.watch(smsQueueProvider('detected')).value?.length ?? 0;

    Widget section(int index, String title, List<Widget> rows) => FadeSlideIn(
          index: index,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: title),
              SettingsGroup(children: rows),
            ],
          ),
        );

    Switch toggle(bool value, ValueChanged<bool> onChanged) => Switch(
          value: value,
          activeThumbColor: p.primary,
          onChanged: onChanged,
        );

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            18,
            16,
            18,
            MediaQuery.of(context).padding.bottom + 130,
          ),
          children: [
            FadeSlideIn(child: Text('Settings', style: AppText.display(p.ink))),
            const SizedBox(height: 16),

            // Profile: now shows (and edits) the real saved name instead of a
            // hardcoded one.
            FadeSlideIn(
              index: 1,
              child: Pressable(
                onTap: () => _editName(context, ref, name),
                scale: 0.98,
                child: AppCard(
                  gradient: p.heroGradient,
                  radius: 26,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          name.isEmpty
                              ? '👤'
                              : String.fromCharCode(name.runes.first).toUpperCase(),
                          style: AppText.title(Colors.white).copyWith(fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? 'Add your name' : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.title(Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Local profile · INR · No account needed',
                              style: AppText.caption(
                                Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_rounded, color: Colors.white70, size: 20),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),

            section(2, 'Manage', [
              ListRowTile(
                emoji: '🏦',
                title: 'Accounts',
                onTap: () =>
                    AppRoutes.push(context, const AccountsManagementScreen()),
              ),
              ListRowTile(
                emoji: '🏷',
                title: 'Categories',
                onTap: () =>
                    AppRoutes.push(context, const CategoriesManagementScreen()),
              ),
              ListRowTile(
                emoji: '#️⃣',
                title: 'Tags',
                onTap: () =>
                    AppRoutes.push(context, const TagsManagementScreen()),
              ),
              ListRowTile(
                emoji: '🔁',
                title: 'Recurring payments',
                onTap: () =>
                    AppRoutes.push(context, const RecurringPaymentsScreen()),
              ),
              ListRowTile(
                emoji: '🧾',
                title: 'Receipts',
                onTap: () =>
                    AppRoutes.push(context, const ReceiptGalleryScreen()),
              ),
            ]),
            const SizedBox(height: 22),

            // These two used to be a "SMS Detection" link and a "Location" row
            // that only showed a snackbar; the onboarding choices behind them
            // were never read. They are real switches now.
            section(3, 'Automation', [
              ListRowTile(
                emoji: '💬',
                title: 'Detect bank SMS',
                subtitle: 'Queue transaction messages for your review',
                trailing: toggle(
                  smsOn,
                  (v) => _togglePermissionPref(
                    context: context,
                    value: v,
                    notifier: ref.read(autoSmsDetectionProvider.notifier),
                    requestPermission: PermissionService.requestSmsPermission,
                    deniedMessage:
                        'SMS permission is needed to detect bank messages. You can allow it in Android Settings.',
                  ),
                ),
              ),
              ListRowTile(
                emoji: '📨',
                title: 'Review detected messages',
                subtitle: waiting > 0
                    ? '$waiting waiting for review'
                    : 'Nothing waiting',
                onTap: () => AppRoutes.push(context, const SmsReviewScreen()),
              ),
              ListRowTile(
                emoji: '📍',
                title: 'Save location with expenses',
                subtitle: 'Captured only at the moment you save',
                trailing: toggle(
                  locationOn,
                  (v) => _togglePermissionPref(
                    context: context,
                    value: v,
                    notifier: ref.read(autoLocationCaptureProvider.notifier),
                    requestPermission:
                        PermissionService.requestLocationPermission,
                    deniedMessage:
                        'Location permission is needed. You can allow it in Android Settings.',
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 22),

            section(4, 'Data', [
              ListRowTile(
                emoji: '💾',
                title: 'Backup & data',
                subtitle: 'Backup, restore, export and import',
                onTap: () =>
                    AppRoutes.push(context, const BackupRestoreScreen()),
              ),
              ListRowTile(
                emoji: '🗑',
                title: 'Recently deleted',
                onTap: () =>
                    AppRoutes.push(context, const RecentlyDeletedScreen()),
              ),
            ]),
            const SizedBox(height: 22),

            section(5, 'App', [
              ListRowTile(
                emoji: '🔒',
                title: 'Biometric lock',
                subtitle: 'Ask for fingerprint, face or PIN on open',
                trailing: toggle(
                  auth.isBiometricsEnabled,
                  (v) => _toggleBiometrics(context, ref, v),
                ),
              ),
              ListRowTile(
                emoji: '🎨',
                title: 'Appearance',
                subtitle: themeMode == ThemeMode.dark ? 'Dark' : 'Light',
                onTap: () => _showAppearanceSheet(context),
              ),
              ListRowTile(
                emoji: 'ℹ️',
                title: 'About',
                onTap: () => _showAbout(context),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
