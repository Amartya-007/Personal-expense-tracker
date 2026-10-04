// Bug Condition Exploration Test — Task 1
//
// Property 1: Default Theme Is Light on First Launch
//   Validates: Requirements 2.1, 2.2
//
// PURPOSE: This test encodes the EXPECTED behavior (state == ThemeMode.light).
// On UNFIXED code it will FAIL because the notifier falls back to ThemeMode.system,
// which is exactly the counterexample that proves the bug exists.
// After the fix is applied, this same test should PASS.
//
// CRITICAL: Do NOT modify the test or the production code when this test fails.
// The failure IS the proof of the bug.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mykhata/presentation/providers/settings_providers.dart';
import 'package:mykhata/core/constants/app_constants.dart';

void main() {
  // Ensure the flutter binding is initialised so SharedPreferences can
  // register its mock platform channel.
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'Property 1 — Bug Condition: Default Theme Is System Instead of Light',
    () {
      // -----------------------------------------------------------------------
      // Bug Condition Case 1: savedThemePreference = null (first launch, empty prefs)
      //
      // isBugCondition_DefaultTheme(X) = true  because  X.savedThemePreference = null
      // Expected: state == ThemeMode.light
      // On unfixed code: state == ThemeMode.system  ← COUNTEREXAMPLE
      // -----------------------------------------------------------------------
      test(
        'Case 1 — no saved preference (first launch): state should be ThemeMode.light',
        () async {
          // Simulate a completely empty SharedPreferences (no prefThemeMode key).
          SharedPreferences.setMockInitialValues({});

          final notifier = ThemeModeNotifier();
          // Wait for the async load() call initiated in the constructor to finish.
          await Future<void>.delayed(Duration.zero);

          // ASSERTION: Expected behavior (fixes the bug).
          // On UNFIXED code this will FAIL: actual state is ThemeMode.system.
          // Counterexample: ThemeModeNotifier.state == ThemeMode.system on first launch.
          expect(
            notifier.state,
            equals(ThemeMode.light),
            reason:
                'BUG DETECTED: ThemeModeNotifier defaults to ThemeMode.system '
                'when no theme preference is saved. Expected ThemeMode.light. '
                'Counterexample: state=${notifier.state} with savedThemePreference=null.',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Bug Condition Case 2: savedThemePreference = 'system' (explicit system pref)
      //
      // isBugCondition_DefaultTheme(X) = true  because  X.savedThemePreference = 'system'
      // The user never explicitly chose 'system'; this value can only arrive via
      // the old else-branch fallback writing 'system' to prefs.
      // Expected: state == ThemeMode.light
      // On unfixed code: state == ThemeMode.system  ← COUNTEREXAMPLE
      // -----------------------------------------------------------------------
      test(
        "Case 2 — saved preference is 'system': state should be ThemeMode.light",
        () async {
          // Simulate prefs where the old fallback persisted 'system'.
          SharedPreferences.setMockInitialValues({
            AppConstants.prefThemeMode: 'system',
          });

          final notifier = ThemeModeNotifier();
          await Future<void>.delayed(Duration.zero);

          // ASSERTION: Expected behavior after fix.
          // On UNFIXED code this will FAIL: actual state is ThemeMode.system.
          // Counterexample: ThemeModeNotifier.state == ThemeMode.system
          //                 when savedThemePreference='system'.
          expect(
            notifier.state,
            equals(ThemeMode.light),
            reason:
                "BUG DETECTED: ThemeModeNotifier returns ThemeMode.system "
                "when saved preference is 'system'. Expected ThemeMode.light. "
                "Counterexample: state=${notifier.state} with savedThemePreference='system'.",
          );
        },
      );

      // -----------------------------------------------------------------------
      // Bug Condition Case 3: Initial constructor seed before load() completes
      //
      // Even before the async load() resolves, the notifier seeds with
      // ThemeMode.system. The expected seed should be ThemeMode.light.
      // -----------------------------------------------------------------------
      test(
        'Case 3 — constructor seed before load() completes: should be ThemeMode.light',
        () {
          SharedPreferences.setMockInitialValues({});

          final notifier = ThemeModeNotifier();

          // Synchronous check — load() is async and hasn't resolved yet.
          // On UNFIXED code: state == ThemeMode.system (the constructor seed).
          expect(
            notifier.state,
            equals(ThemeMode.light),
            reason:
                'BUG DETECTED: ThemeModeNotifier constructor seeds ThemeMode.system '
                'instead of ThemeMode.light. The initial render before load() '
                'completes will show system theme instead of light. '
                'Counterexample: notifier.state == ThemeMode.system immediately '
                'after construction with no saved preference.',
          );
        },
      );
    },
  );
}
