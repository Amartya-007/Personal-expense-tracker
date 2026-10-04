import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Trigger biometric check automatically as early as possible on frame load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleUnlock();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? AppColors.darkInk : AppColors.ink;
    final mutedColor = isDark ? AppColors.darkMuted : AppColors.muted;
    final surface2Color = isDark ? AppColors.darkSurface2 : AppColors.surface2;
    final isUnlocked = ref.watch(authProvider).isUnlocked;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 📒 Notebook icon in squircle
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('📒', style: TextStyle(fontSize: 34)),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'MyKhata',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: inkColor,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Locked',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: mutedColor,
                  ),
                ),

                const SizedBox(height: 48),

                // Pulsating Fingerprint Sensor (tap to manual retry if prompt was cancelled)
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: GestureDetector(
                    onTap: _handleUnlock,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: isUnlocked ? AppColors.income : surface2Color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isUnlocked ? AppColors.income : AppColors.primary).withValues(alpha: 0.25),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
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
                ),

                const SizedBox(height: 24),

                Text(
                  'Touch sensor or tap below to unlock',
                  style: TextStyle(
                    fontSize: 13,
                    color: mutedColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 8),

                TextButton(
                  onPressed: _handleUnlock,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text(
                    'Use device PIN / Biometrics',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
