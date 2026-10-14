import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/theme/app_theme.dart';
import 'package:mykhata/presentation/screens/onboarding/widgets/onboarding_illustrations.dart';

/// Reduce-motion contract for the new onboarding illustrations: with
/// `disableAnimations` on, each animated illustration pins its controllers to
/// the static end-state and schedules no ongoing frames, so `pump()` settles
/// immediately (no pending transient callbacks). With motion on, the repeating
/// illustrations keep scheduling frames.
void main() {
  Widget host({required bool disableAnimations, required Widget child}) =>
      MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: Center(child: child)),
        ),
      );

  for (final entry in <String, Widget>{
    'logo': const OnbLogoArt(),
    'sms': const OnbSmsArt(),
    'receipt': const OnbReceiptArt(),
    'budget': const OnbBudgetArt(),
    'done': const OnbDoneArt(),
    'fingerprint': const OnbFingerprint(),
  }.entries) {
    testWidgets('${entry.key}: reduce-motion renders a static end-state', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(disableAnimations: true, child: entry.value),
      );
      await tester.pump();

      // No animation is driving: the frame scheduler has nothing pending, so
      // the widget is at its settled end-state.
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(find.byWidget(entry.value), findsOneWidget);
    });
  }

  testWidgets('logo keeps animating when motion is enabled', (tester) async {
    await tester.pumpWidget(
      host(disableAnimations: false, child: const OnbLogoArt()),
    );
    await tester.pump();

    // The orbit/float controllers repeat, so a frame is always scheduled.
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('done confetti emits nothing under reduce-motion', (
    tester,
  ) async {
    // The painter paints the dispersed/faded end-state (nothing) rather than a
    // mid-burst frame; the widget still mounts and settles with no pending
    // frames.
    await tester.pumpWidget(
      host(disableAnimations: true, child: const OnbDoneArt()),
    );
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
