import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../services/export/export_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_providers.dart';
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

  void _showProfileSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Profile',
              style: GoogleFonts.sora(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            _buildProfileRow('👤', 'Name', 'Amar', isDark),
            _buildProfileRow('₹', 'Currency', 'INR only', isDark),
            _buildProfileRow(
              '💳',
              'Default Account',
              'Primary Account',
              isDark,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAppearanceSheet(BuildContext context, WidgetRef ref, bool isDark) {
    final currentTheme = ref.watch(themeModeProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Appearance',
              style: GoogleFonts.sora(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surface2Dark
                    : AppColors.surface2Light,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _buildThemeOption(
                    'System',
                    currentTheme == ThemeMode.system,
                    () {
                      ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.system);
                      Navigator.pop(ctx);
                    },
                    isDark,
                  ),
                  _buildThemeOption(
                    'Light',
                    currentTheme == ThemeMode.light,
                    () {
                      ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.light);
                      Navigator.pop(ctx);
                    },
                    isDark,
                  ),
                  _buildThemeOption('Dark', currentTheme == ThemeMode.dark, () {
                    ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(ThemeMode.dark);
                    Navigator.pop(ctx);
                  }, isDark),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showImportExportSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Import / Export',
              style: GoogleFonts.sora(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Text('⬆️', style: TextStyle(fontSize: 22)),
              title: Text(
                'Export CSV',
                style: GoogleFonts.sora(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Written in small batches',
                style: GoogleFonts.sora(fontSize: 12),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                // BUG FIX: capture messenger before await; wrap in try/catch.
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final file = await ExportService().exportToCsv();
                  messenger.showSnackBar(
                    SnackBar(content: Text('Exported CSV to ${file.path}')),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Export failed: $e')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Text('📄', style: TextStyle(fontSize: 22)),
              title: Text(
                'Export PDF Report',
                style: GoogleFonts.sora(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Date range, totals and summaries',
                style: GoogleFonts.sora(fontSize: 12),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                // BUG FIX: capture messenger before await; wrap in try/catch.
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final file = await ExportService().generatePdfReport();
                  messenger.showSnackBar(
                    SnackBar(content: Text('Generated PDF at ${file.path}')),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('PDF export failed: $e')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: isDark ? AppColors.primaryDark : AppColors.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Center(
                child: Text('📒', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'MyKhata',
              style: GoogleFonts.sora(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Version 1.0 · Offline · No ads · No login',
              style: GoogleFonts.sora(
                fontSize: 12.5,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    String title,
    bool isSelected,
    VoidCallback onTap,
    bool isDark,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.surfaceDark : AppColors.surfaceLight)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: isSelected
                ? [
                    isDark
                        ? AppColors.cardShadowDark
                        : AppColors.cardShadowLight,
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              title,
              style: GoogleFonts.sora(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight)
                    : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildProfileRow(
    String emoji,
    String title,
    String value,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.sora(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.sora(
              fontSize: 13,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.of(context).padding.bottom + 130),
          children: [
            // Title
            Text(
              'Settings',
              style: GoogleFonts.sora(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 16),

            // Profile Hero Banner
            InkWell(
              onTap: () => _showProfileSheet(context, isDark),
              borderRadius: BorderRadius.circular(26),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: isDark
                      ? AppColors.heroGradientDark
                      : AppColors.heroGradientLight,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5B3DF5).withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          'A',
                          style: GoogleFonts.sora(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Amar',
                            style: GoogleFonts.sora(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Local profile · INR · No account needed',
                            style: GoogleFonts.sora(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Card Group 1: Data & Categories
            _buildSettingsCard(isDark, [
              _buildRow(
                '👤',
                'Profile',
                isDark,
                onTap: () => _showProfileSheet(context, isDark),
              ),
              _buildRow(
                '🏦',
                'Accounts',
                isDark,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AccountsManagementScreen(),
                    ),
                  );
                },
              ),
              _buildRow(
                '🏷',
                'Categories',
                isDark,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CategoriesManagementScreen(),
                    ),
                  );
                },
              ),
              _buildRow(
                '#️⃣',
                'Tags',
                isDark,
                isLast: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TagsManagementScreen(),
                    ),
                  );
                },
              ),
            ]),

            const SizedBox(height: 14),

            // Card Group 2: Features & Automation
            _buildSettingsCard(isDark, [
              _buildRow(
                '🔁',
                'Recurring Payments',
                isDark,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RecurringPaymentsScreen(),
                    ),
                  );
                },
              ),
              _buildRow(
                '🧾',
                'Receipts',
                isDark,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ReceiptGalleryScreen(),
                    ),
                  );
                },
              ),
              _buildRow(
                '💬',
                'SMS Detection',
                isDark,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SmsReviewScreen()),
                  );
                },
              ),
              _buildRow(
                '📍',
                'Location',
                isDark,
                isLast: true,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Location is captured on transaction save when permitted.',
                      ),
                    ),
                  );
                },
              ),
            ]),

            const SizedBox(height: 14),

            // Card Group 3: System & Security
            _buildSettingsCard(isDark, [
              _buildRow(
                '💾',
                'Backup & Restore',
                isDark,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BackupRestoreScreen(),
                    ),
                  );
                },
              ),
              _buildRow(
                '⇅',
                'Import / Export',
                isDark,
                onTap: () => _showImportExportSheet(context, isDark),
              ),
              _buildRow(
                '🗑',
                'Recently Deleted',
                isDark,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RecentlyDeletedScreen(),
                    ),
                  );
                },
              ),
              _buildRow(
                '🔒',
                'Security',
                isDark,
                trailing: Switch(
                  value: authState.isBiometricsEnabled,
                  activeThumbColor: isDark
                      ? AppColors.primaryDark
                      : AppColors.primary,
                  onChanged: (val) async {
                    final messenger = ScaffoldMessenger.of(context);
                    final success = await ref
                        .read(authProvider.notifier)
                        .toggleBiometrics(val);
                    if (!success && val) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Unable to enable biometrics. Please ensure biometrics or device screen lock is set up in Android Settings.',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
              _buildRow(
                '🎨',
                'Appearance',
                isDark,
                onTap: () => _showAppearanceSheet(context, ref, isDark),
              ),
              _buildRow(
                'ℹ️',
                'About',
                isDark,
                isLast: true,
                onTap: () => _showAboutDialog(context, isDark),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
        ],
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.0,
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildRow(
    String emoji,
    String title,
    bool isDark, {
    VoidCallback? onTap,
    Widget? trailing,
    bool isLast = false,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(isLast ? 20 : 0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surface2Dark
                        : AppColors.surface2Light,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 19)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.sora(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
                trailing ??
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            height: 1,
          ),
      ],
    );
  }
}
