// Preservation Property Tests — Task 2
//
// Property 3: Preservation — Explicit Theme Preferences Are Respected
//   Validates: Requirements 3.1, 3.2
//
// PURPOSE: Establish the baseline behavior of ThemeModeNotifier on UNFIXED code
// for inputs that are NOT in the bug condition domain (i.e., savedThemePreference
// is 'light' or 'dark'). These tests MUST PASS on unfixed code, confirming the
// behaviors we must preserve through the fix.
//
// OBSERVATION-FIRST METHODOLOGY:
//   - 'light' saved → ThemeMode.light        (observed, must be preserved)
//   - 'dark'  saved → ThemeMode.dark         (observed, must be preserved)
// These paths are unaffected by the else-branch bug, so they pass today and
// must continue to pass after the fix.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mykhata/presentation/providers/settings_providers.dart';
import 'package:mykhata/core/constants/app_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // Helper: build a ThemeModeNotifier with a specific saved preference and wait
  // for the async load() to complete.
  // ---------------------------------------------------------------------------
  Future<ThemeModeNotifier> buildNotifierWith(String prefValue) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.prefThemeMode: prefValue,
    });
    final notifier = ThemeModeNotifier();
    await Future<void>.delayed(Duration.zero);
    return notifier;
  }

  // ---------------------------------------------------------------------------
  // Unit tests — concrete, observed baseline cases
  // ---------------------------------------------------------------------------
  group('Preservation Unit Tests — Saved Theme Preferences Are Respected', () {
    test(
      "Observation 1 — prefThemeMode = 'light': load() produces ThemeMode.light",
      () async {
        final notifier = await buildNotifierWith('light');

        // Validates: Requirement 3.2 — explicit 'light' preference is respected
        expect(
          notifier.state,
          equals(ThemeMode.light),
          reason:
              "When prefThemeMode='light' is saved, ThemeModeNotifier.load() "
              'must resolve to ThemeMode.light. This must be preserved by any fix.',
        );
      },
    );

    test(
      "Observation 2 — prefThemeMode = 'dark': load() produces ThemeMode.dark",
      () async {
        final notifier = await buildNotifierWith('dark');

        // Validates: Requirement 3.1 — explicit 'dark' preference is respected
        expect(
          notifier.state,
          equals(ThemeMode.dark),
          reason:
              "When prefThemeMode='dark' is saved, ThemeModeNotifier.load() "
              'must resolve to ThemeMode.dark. This must be preserved by any fix.',
        );
      },
    );

    test(
      'Observation 3 — setThemeMode(ThemeMode.dark) persists dark and reloads correctly',
      () async {
        SharedPreferences.setMockInitialValues({});
        final notifier = ThemeModeNotifier();
        await Future<void>.delayed(Duration.zero);

        await notifier.setThemeMode(ThemeMode.dark);

        // The state is updated in-place by setThemeMode, no re-load needed.
        expect(
          notifier.state,
          equals(ThemeMode.dark),
          reason:
              'setThemeMode(ThemeMode.dark) must update state to ThemeMode.dark.',
        );

        // Verify the value was actually written to SharedPreferences by creating
        // a fresh notifier that reads from the same mock store.
        final notifier2 = ThemeModeNotifier();
        await Future<void>.delayed(Duration.zero);
        expect(
          notifier2.state,
          equals(ThemeMode.dark),
          reason:
              "A fresh ThemeModeNotifier should read the 'dark' value persisted "
              'by setThemeMode and produce ThemeMode.dark.',
        );
      },
    );

    test(
      'Observation 4 — setThemeMode(ThemeMode.light) persists light and reloads correctly',
      () async {
        SharedPreferences.setMockInitialValues({
          AppConstants.prefThemeMode: 'dark',
        });
        final notifier = ThemeModeNotifier();
        await Future<void>.delayed(Duration.zero);
        expect(notifier.state, equals(ThemeMode.dark)); // sanity check

        await notifier.setThemeMode(ThemeMode.light);
        expect(
          notifier.state,
          equals(ThemeMode.light),
          reason: 'Switching from dark to light must update state immediately.',
        );

        final notifier2 = ThemeModeNotifier();
        await Future<void>.delayed(Duration.zero);
        expect(
          notifier2.state,
          equals(ThemeMode.light),
          reason:
              "A fresh notifier must read the 'light' value and produce ThemeMode.light.",
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Property-based tests — iterate over the non-buggy input domain
  //
  // For all prefThemeMode values that are 'light' or 'dark', the notifier
  // produces the correct ThemeMode (Requirements 3.1, 3.2).
  //
  // Validates: Requirements 3.1, 3.2
  // ---------------------------------------------------------------------------
  group(
    'Property 3 — Preservation: Explicit Theme Preferences Are Respected '
    '(Validates: Requirements 3.1, 3.2)',
    () {
      // The complete domain of preservation-checked inputs:
      // the two explicit saved preference values that are NOT the bug condition.
      const preservedInputs = <(String, ThemeMode)>[
        ('light', ThemeMode.light),
        ('dark', ThemeMode.dark),
      ];

      // Iterate over all inputs in the preservation domain.
      for (final (prefValue, expectedMode) in preservedInputs) {
        test(
          "prefThemeMode='$prefValue' → ThemeMode.$prefValue (preservation holds)",
          () async {
            final notifier = await buildNotifierWith(prefValue);

            // Property assertion: for all X in the preservation domain,
            // ThemeModeNotifier_original(X).state == ThemeModeNotifier_fixed(X).state
            // (On unfixed code this simply checks the current correct behavior.)
            expect(
              notifier.state,
              equals(expectedMode),
              reason:
                  "Preservation property: prefThemeMode='$prefValue' must always "
                  'produce $expectedMode. This must hold before AND after the fix.',
            );
          },
        );
      }

      // Extended property: simulate multiple round-trips to verify setThemeMode
      // and load() are consistent for each preserved value.
      for (final (prefValue, expectedMode) in preservedInputs) {
        test(
          "Round-trip property: setThemeMode then load() preserves '$prefValue'",
          () async {
            SharedPreferences.setMockInitialValues({});
            final notifier = ThemeModeNotifier();
            await Future<void>.delayed(Duration.zero);

            // Set the explicit preference
            await notifier.setThemeMode(expectedMode);

            // A new notifier reading from the same prefs must reproduce the same state
            final notifier2 = ThemeModeNotifier();
            await Future<void>.delayed(Duration.zero);

            expect(
              notifier2.state,
              equals(expectedMode),
              reason:
                  'Round-trip property: after setThemeMode($expectedMode), a fresh '
                  'notifier loaded from the same SharedPreferences must produce '
                  '$expectedMode.',
            );
          },
        );
      }
    },
  );
}
