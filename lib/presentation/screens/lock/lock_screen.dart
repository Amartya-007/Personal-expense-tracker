import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/pressable.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Trigger the biometric prompt as early as possible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handleUnlock();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleUnlock() async {
    await ref.read(authProvider.notifier).authenticate();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isUnlocked = ref.watch(authProvider).isUnlocked;
    final accent = isUnlocked ? p.income : p.primary;

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: FadeSlideIn(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: p.heroGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: p.primary.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text('📒', style: TextStyle(fontSize: 34)),
                  ),
                  const SizedBox(height: 18),
                  Text('MyKhata', style: AppText.display(p.ink)),
                  const SizedBox(height: 4),
                  Text('Locked', style: AppText.caption(p.muted)),
                  const SizedBox(height: 48),

                  // Pulsing unlock button (tap to retry if the prompt was
                  // dismissed).
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Pressable(
                      onTap: _handleUnlock,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: isUnlocked ? p.income : p.surface2,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.28),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isUnlocked ? '✓' : '👆',
                          style: TextStyle(
                            fontSize: 42,
                            color: isUnlocked ? Colors.white : null,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),
                  Text(
                    'Touch the sensor to unlock',
                    textAlign: TextAlign.center,
                    style: AppText.caption(p.muted),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _handleUnlock,
                    child: const Text('Use device PIN / biometrics'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
