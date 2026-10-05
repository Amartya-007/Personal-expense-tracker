import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import 'app_card.dart';
import 'skeleton.dart';

/// Renders an [AsyncValue] with a skeleton while loading and an inline error
/// card (with optional retry) on failure. Replaces the `when(...)` boilerplate
/// that every dashboard section repeated.
///
/// Reloads keep showing the previous data instead of flashing the skeleton,
/// so pull-to-refresh and edits don't make sections blink.
class AsyncSection<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final double skeletonHeight;
  final String errorLabel;
  final VoidCallback? onRetry;

  const AsyncSection({
    super.key,
    required this.value,
    required this.builder,
    this.skeletonHeight = 110,
    this.errorLabel = 'Could not load this section',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnReload: true,
      data: builder,
      loading: () => SkeletonCard(height: skeletonHeight),
      error: (err, _) => ErrorCard(message: errorLabel, onRetry: onRetry),
    );
  }
}

class ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorCard({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      shadow: false,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: p.expense),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: AppText.caption(p.muted))),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
