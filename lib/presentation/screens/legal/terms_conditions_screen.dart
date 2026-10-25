import 'package:flutter/material.dart';

import '../../../core/legal/legal_content.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../widgets/app_card.dart';
import '../../widgets/fade_slide_in.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        title: Text('Terms & Conditions', style: AppText.title(p.ink)),
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
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: p.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Text('📜', style: TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Terms of Service',
                          style: AppText.bodyStrong(p.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Guidelines for using MyKhata',
                          style: AppText.caption(p.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FadeSlideIn(
            index: 1,
            child: Text(
              'Last updated: ${LegalContent.termsLastUpdated}',
              style: AppText.caption(p.muted),
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < LegalContent.termsSections.length; i++) ...[
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
                        LegalContent.termsSections[i].title,
                        style: AppText.bodyStrong(p.ink),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        LegalContent.termsSections[i].body,
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
