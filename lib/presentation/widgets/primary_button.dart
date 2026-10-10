import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import 'pressable.dart';

/// Full-width primary call-to-action: a teal gradient with a soft coloured
/// glow, press feedback with a haptic tick, and a built-in loading state.
/// When disabled it drops to a flat, quiet surface so it is obviously inert.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onPressed != null && !loading;
    final fg = enabled || loading ? p.onPrimary : p.muted;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Pressable(
        onTap: enabled ? onPressed : null,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: enabled || loading
                ? LinearGradient(
                    colors: [
                      p.primary,
                      Color.lerp(p.primary, Colors.black, 0.22)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: enabled || loading ? null : p.surface2,
            borderRadius: BorderRadius.circular(20),
            boxShadow: enabled ? [p.primaryGlow] : null,
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: AppMotion.fast,
            child: loading
                ? SizedBox(
                    key: const ValueKey('loading'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: p.onPrimary,
                    ),
                  )
                : Row(
                    key: const ValueKey('label'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 20, color: fg),
                        const SizedBox(width: 8),
                      ],
                      Text(label, style: AppText.button(fg)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
