import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/presentation/widgets/fade_slide_in.dart';

/// Reduce-motion contract: with `disableAnimations` on, [FadeSlideIn] jumps
/// straight to its settled state (opacity 1, no offset) on the first frame;
/// with it off, the entrance is still animating right after mount.
void main() {
  Widget host({required bool disableAnimations}) => MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: const Directionality(
      textDirection: TextDirection.ltr,
      child: FadeSlideIn(child: SizedBox(width: 50, height: 50)),
    ),
  );

  testWidgets('reduce-motion skips the entrance animation', (tester) async {
    await tester.pumpWidget(host(disableAnimations: true));
    await tester.pump();

    final opacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byType(FadeSlideIn),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, 1.0);
  });

  testWidgets('motion enabled keeps the entrance animating on first frame', (
    tester,
  ) async {
    await tester.pumpWidget(host(disableAnimations: false));
    await tester.pump();

    final opacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byType(FadeSlideIn),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, lessThan(1.0));

    await tester.pumpAndSettle();
  });
}
