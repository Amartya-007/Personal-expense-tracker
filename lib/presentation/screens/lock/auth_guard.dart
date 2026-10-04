import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../providers/auth_provider.dart';
import 'lock_screen.dart';

/// App-wide lock gate. It wraps the whole navigator (installed through
/// `MaterialApp.builder`), so it is the single place the lock state is
/// checked and it covers *every* screen.
///
/// SECURITY FIX: the lock screen used to be the root route, so any screen
/// pushed on top of it (add transaction, detail, settings pages) stayed
/// visible after the app re-locked. While locked, the app is now hidden with
/// [Offstage] (nothing painted, no touches, no semantics) but its state is
/// kept, so a half-filled form survives a trip to the camera or file picker.
class AuthGuard extends ConsumerWidget {
  final Widget child;

  /// Hide the app until the stored biometric setting has loaded. Disabled
  /// during onboarding, when there is no private data to protect yet.
  final bool blockWhileLoading;

  const AuthGuard({
    super.key,
    required this.child,
    this.blockWhileLoading = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final loading = !auth.isReady;
    final locked = loading ? blockWhileLoading : !auth.isUnlocked;

    // Don't leave the keyboard open behind the lock screen.
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (!next.isUnlocked) FocusManager.instance.primaryFocus?.unfocus();
    });

    final Widget overlay;
    if (loading) {
      // Neutral splash while the biometric setting loads, so private screens
      // never flash before the lock appears.
      overlay = blockWhileLoading
          ? const SizedBox.expand(key: ValueKey('auth-splash'))
          : const SizedBox.shrink(key: ValueKey('auth-open'));
    } else if (!auth.isUnlocked) {
      overlay = const LockScreen(key: ValueKey('auth-lock'));
    } else {
      overlay = const SizedBox.shrink(key: ValueKey('auth-open'));
    }

    return ColoredBox(
      color: context.palette.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(offstage: locked, child: child),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !locked,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: overlay,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
