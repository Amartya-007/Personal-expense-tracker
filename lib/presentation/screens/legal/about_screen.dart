import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text.dart';
import '../../widgets/app_card.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/list_widgets.dart';

import 'privacy_policy_screen.dart';
import 'terms_conditions_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        title: Text('About MyKhata', style: AppText.title(p.ink)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          18,
          12,
          18,
          MediaQuery.of(context).padding.bottom + 24,
        ),
        children: [
          FadeSlideIn(
            child: Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: p.heroGradient,
                      borderRadius: BorderRadius.circular(AppRadius.dialog),
                      boxShadow: [
                        BoxShadow(
                          color: p.primary.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text('📒', style: TextStyle(fontSize: 40)),
                  ),
                  const SizedBox(height: 14),
                  Text(AppConstants.appName, style: AppText.display(p.ink)),
                  const SizedBox(height: 4),
                  Text(
                    'Version ${AppConstants.appVersion} (Build 1)',
                    style: AppText.caption(p.muted).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: p.primarySoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '100% Offline · No Ads · No Account Needed',
                      style: AppText.caption(p.primary).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FadeSlideIn(
            index: 1,
            child: AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Core Principles', style: AppText.bodyStrong(p.ink)),
                  const SizedBox(height: 10),
                  _featureRow(p, '🔒', 'Private & Secure', 'All data is saved locally on your device SQLite database.'),
                  _featureRow(p, '💬', 'Bank SMS Review', 'Detects bank transaction messages on-device for manual review.'),
                  _featureRow(p, '👥', 'Split Expenses & Groups', 'Split bills equally, by percentages or shares. Optional contact access with full offline privacy.'),
                  _featureRow(p, '🎯', 'Smart Budgets', 'Set monthly or category limits with early nudge alerts.'),
                  _featureRow(p, '💾', 'Full Data Ownership', 'Export ZIP backups, CSV, or PDF reports whenever you want.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          FadeSlideIn(
            index: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LEGAL & LICENSES', style: AppText.section(p.muted)),
                const SizedBox(height: 8),
                SettingsGroup(
                  children: [
                    ListRowTile(
                      emoji: '🛡️',
                      title: 'Privacy Policy',
                      subtitle: 'How your data is handled on-device',
                      onTap: () => AppRoutes.push(context, const PrivacyPolicyScreen()),
                    ),
                    ListRowTile(
                      emoji: '📜',
                      title: 'Terms & Conditions',
                      subtitle: 'Terms of use and financial advice disclaimers',
                      onTap: () => AppRoutes.push(context, const TermsConditionsScreen()),
                    ),
                    ListRowTile(
                      emoji: '🔤',
                      title: 'Open-source licenses',
                      subtitle: 'Third-party libraries and licenses',
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: AppConstants.appName,
                        applicationVersion: 'Version ${AppConstants.appVersion}',
                        applicationIcon: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: p.heroGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text('📒', style: TextStyle(fontSize: 24)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FadeSlideIn(
            index: 3,
            child: AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: p.muted, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'MyKhata operates completely offline. No user data is collected, stored on external servers, or sold to third parties.',
                      style: AppText.caption(p.muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureRow(AppPalette p, String emoji, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.bodyStrong(p.ink)),
                const SizedBox(height: 1),
                Text(subtitle, style: AppText.caption(p.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
