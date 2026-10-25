import 'package:flutter/material.dart';

import '../../../core/legal/legal_content.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../widgets/app_card.dart';
import '../../widgets/fade_slide_in.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        title: Text('Privacy Policy', style: AppText.title(p.ink)),
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
            child: AppCard(
              gradient: p.heroGradientSoft,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Text('🛡️', style: TextStyle(fontSize: 22)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '100% Private & Offline',
                              style: AppText.title(Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Your financial data stays on your phone',
                              style: AppText.caption(
                                Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'MyKhata is designed from the ground up to respect your financial privacy. '
                    'No servers. No cloud databases. No advertising trackers.',
                    style: AppText.caption(Colors.white.withValues(alpha: 0.9)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FadeSlideIn(
            index: 1,
            child: Text(
              'Last updated: ${LegalContent.privacyPolicyLastUpdated}',
              style: AppText.caption(p.muted),
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < LegalContent.privacyPolicySections.length; i++) ...[
            FadeSlideIn(
              index: i + 2,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LegalContent.privacyPolicySections[i].title,
                        style: AppText.bodyStrong(p.ink),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        LegalContent.privacyPolicySections[i].body,
                        style: AppText.body(p.muted).copyWith(
                          fontSize: 13.5,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
