# Implementation Plan

- [x] 1. Write bug condition exploration tests
  - **Property 1: Bug Condition** - Default Theme Is System Instead of Light
  - **CRITICAL**: This test MUST FAIL on unfixed code — failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior — it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples demonstrating the default-theme bug exists
  - **Scoped PBT Approach**: Scope the property to the concrete failing case — `savedThemePreference = null` (first launch, no saved pref)
  - Create `ThemeModeNotifier` with empty `SharedPreferences` (no `prefThemeMode` key)
  - Assert that after `load()` completes, `state == ThemeMode.light` (from Bug Condition: `isBugCondition_DefaultTheme(X)` where `X.savedThemePreference = null`)
  - Also test `savedThemePreference = 'system'` — assert `state == ThemeMode.light` (from `isBugCondition_DefaultTheme`)
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS — `state` is `ThemeMode.system` instead of `ThemeMode.light` (proves bug exists)
  - Document counterexample found (e.g., `ThemeModeNotifier.state` equals `ThemeMode.system` on first launch)
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.1, 1.2, 2.1, 2.2_

- [x] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Saved Theme Preferences and Non-SMS Permissions Are Unchanged
  - **IMPORTANT**: Follow observation-first methodology
  - **Observe on UNFIXED code** (non-buggy inputs — cases where `isBugCondition_DefaultTheme` and `isBugCondition_SmsPermission` are false):
    - Observe: `ThemeModeNotifier.load()` with `prefThemeMode = 'light'` → `ThemeMode.light`
    - Observe: `ThemeModeNotifier.load()` with `prefThemeMode = 'dark'` → `ThemeMode.dark`
    - Observe: `requestSmsPermission()` when `Permission.sms.request()` returns `granted` → `true`
    - Observe: `requestSmsPermission()` when `Permission.sms.request()` returns `denied` → `false`
    - Observe: `requestLocationPermission()`, `requestCameraPermission()`, `requestNotificationPermission()` — behavior is unaffected
  - Write property-based test: for all `prefThemeMode` values that are `'light'` or `'dark'`, the fixed notifier produces the same `ThemeMode` as the original (from Preservation Requirements 3.1, 3.2)
  - Write property-based test: for all exception-free SMS permission outcomes (`granted`, `denied`, `permanentlyDenied`), `requestSmsPermission()` returns the same result as the original (from Preservation Requirements 3.4)
  - Write unit tests asserting `requestLocationPermission()`, `requestCameraPermission()`, and `requestNotificationPermission()` are completely unchanged (from Preservation Requirements 3.5, 3.6)
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.4, 3.5, 3.6_

- [x] 3. Fix Default Theme and SMS Permission Crash

  - [x] 3.1 Fix default theme fallback in `ThemeModeNotifier`
    - File: `lib/presentation/providers/settings_providers.dart`
    - Change constructor seed: `super(ThemeMode.system)` → `super(ThemeMode.light)` so the initial render before `load()` completes uses light mode
    - Change `else` branch in `load()`: `state = ThemeMode.system` → `state = ThemeMode.light` so first-launch falls back to light
    - _Bug_Condition: `isBugCondition_DefaultTheme(X)` where `X.savedThemePreference = null`_
    - _Expected_Behavior: `getInitialThemeMode'(X) = ThemeMode.light` for all `X` satisfying `isBugCondition_DefaultTheme`_
    - _Preservation: For all `X` where `savedThemePreference` is `'light'` or `'dark'`, result is unchanged (Requirements 3.1, 3.2)_
    - _Requirements: 2.1, 2.2, 3.1, 3.2_

  - [x] 3.2 Wrap SMS permission request in try/catch in `PermissionService`
    - File: `lib/core/permissions/permission_service.dart`
    - Wrap `Permission.sms.request()` in `try/catch (_)` that returns `false` on any exception
    - ```dart
      static Future<bool> requestSmsPermission() async {
        try {
          final status = await Permission.sms.request();
          return status.isGranted;
        } catch (_) {
          return false;
        }
      }
      ```
    - No changes needed to `onboarding_screen.dart` — once the callee is safe, the `VoidCallback` pattern is acceptable and navigation via `_completeOnboarding()` is unblocked
    - _Bug_Condition: `isBugCondition_SmsPermission(X)` where `Permission.sms.request()` throws_
    - _Expected_Behavior: `requestSmsPermission'()` returns `false` and no exception propagates_
    - _Preservation: Exception-free SMS outcomes (`granted`, `denied`) return same result as before (Requirement 3.4); other permissions completely unaffected (Requirements 3.5, 3.6)_
    - _Requirements: 2.3, 2.4, 2.5, 3.4, 3.5, 3.6_

  - [x] 3.3 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Default Theme Is Light on First Launch
    - **IMPORTANT**: Re-run the SAME test from task 1 — do NOT write a new test
    - The test from task 1 encodes the expected behavior (`state == ThemeMode.light` when no pref saved)
    - When this test passes, it confirms `ThemeModeNotifier` now defaults to `ThemeMode.light`
    - Run bug condition exploration test from step 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms default theme bug is fixed)
    - _Requirements: 2.1, 2.2_

  - [x] 3.4 Verify preservation tests still pass
    - **Property 2: Preservation** - Saved Theme Preferences and Non-SMS Permissions Are Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 2 — do NOT write new tests
    - Run all preservation property tests from step 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions in theme loading or permission handling)
    - Confirm all tests still pass after fix (no regressions)

- [x] 4. Checkpoint — Ensure all tests pass
  - Run the full test suite and ensure all tests pass
  - Verify: exploration test from task 1 passes (bug is fixed)
  - Verify: preservation tests from task 2 pass (no regressions)
  - Ask the user if any questions arise
