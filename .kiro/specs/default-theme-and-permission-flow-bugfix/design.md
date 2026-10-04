# Default Theme and Permission Flow Bugfix Design

## Overview

This spec covers two independent bugs in the MyKhata Flutter app that both surface during first-run / onboarding:

1. **Default Theme Bug** — `ThemeModeNotifier` in `settings_providers.dart` initializes with `ThemeMode.system` as the Riverpod state seed. When no theme preference has been persisted (first launch), the `load()` method's `else` branch also resolves to `ThemeMode.system`, so the system default is never overridden to `ThemeMode.light`. The fix is minimal: change the fallback in `load()` from `ThemeMode.system` to `ThemeMode.light`.

2. **SMS Permission Crash** — `PermissionService.requestSmsPermission()` in `permission_service.dart` calls `Permission.sms.request()` with no error handling. On some Android OEMs or emulators, this platform call throws a `PlatformException` (e.g., when SMS is permanently denied or the system dialog crashes). Because `_buildPermissionTile` in `onboarding_screen.dart` wraps the async call behind a synchronous `VoidCallback`, the unhandled future error propagates as an uncaught exception, crashing or freezing the onboarding screen. SMS permission is optional; the fix wraps the call in `try/catch` and returns `false` on any error, making the "Get Started" button always functional.

## Glossary

- **Bug_Condition (C)**: The set of inputs / runtime states that trigger either bug.
- **Property (P)**: The desired correct behavior for each bug condition.
- **Preservation**: Behaviors that must remain unchanged after the fix is applied.
- **ThemeModeNotifier**: `StateNotifier<ThemeMode>` in `lib/presentation/providers/settings_providers.dart` that persists and exposes the app theme.
- **PermissionService**: Static utility class in `lib/core/permissions/permission_service.dart` that wraps `permission_handler` calls.
- **OnboardingScreen**: `ConsumerStatefulWidget` in `lib/presentation/screens/onboarding/onboarding_screen.dart`; hosts the account setup and permissions steps.
- **prefThemeMode**: The `SharedPreferences` key used to persist the theme mode string (`'light'` | `'dark'`).

---

## Bug Details

### Bug 1 — Default Theme: Bug Condition

The bug manifests on first app launch when no `prefThemeMode` key exists in `SharedPreferences`. The `load()` method reads `null` for `modeStr` and falls through to the `else` branch, which sets `state = ThemeMode.system`. The notifier's constructor seed is also `ThemeMode.system`, so neither path ever produces `ThemeMode.light` on a fresh install.

**Formal Specification:**

```
FUNCTION isBugCondition_Theme(prefs)
  INPUT: prefs — SharedPreferences snapshot
  OUTPUT: boolean

  RETURN prefs.getString(prefThemeMode) == null
         AND ThemeModeNotifier.state == ThemeMode.system
         AND expected state == ThemeMode.light
END FUNCTION
```

**Examples:**

- First launch, no saved preference → current: `ThemeMode.system` / expected: `ThemeMode.light`
- Fresh install on a device whose system is in dark mode → app incorrectly inherits dark UI
- After clearing app data → same as first launch, bug recurs

---

### Bug 2 — SMS Permission Crash: Bug Condition

The bug manifests when a user taps the "Allow" button on the SMS permission tile during onboarding. `PermissionService.requestSmsPermission()` invokes `Permission.sms.request()`, which can throw a `PlatformException` on certain devices or when SMS is permanently denied. Because the caller uses a synchronous `VoidCallback`, the exception is an unhandled future error, crashing or freezing the screen.

**Formal Specification:**

```
FUNCTION isBugCondition_Sms(event)
  INPUT: event — tap on SMS "Allow" button in OnboardingScreen
  OUTPUT: boolean

  RETURN Permission.sms.request() THROWS exception
         AND requestSmsPermission has no try/catch
         AND unhandled future error crashes/freezes the screen
END FUNCTION
```

**Examples:**

- User taps "Allow" (SMS) on a device where SMS permission is permanently denied → crash
- User taps "Allow" (SMS) on Android emulator that throws `PlatformException` → freeze
- User denies the system SMS dialog → currently returns `false` correctly (no bug); but if the dialog itself errors, crash occurs
- "Get Started" pressed without ever tapping "Allow" (SMS) → navigates correctly (no crash here)

---

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**

- Saving an explicit `'light'` or `'dark'` preference via `setThemeMode()` must continue to persist and reload correctly on subsequent launches.
- When a user has already saved `'dark'` as their preference, the app must still open in dark mode after the fix.
- Location, camera, and notification permission requests must remain completely unaffected.
- The "Get Started" button must navigate to `MainNavigationScreen` regardless of whether any permission was granted.
- Tapping "Allow" on location, camera, or notification tiles must continue to work exactly as before.
- The `checkAllPermissions()` map must continue to return correct values for all four permissions.
- All account setup logic in `_buildAccountStep()` and `_saveFirstAccount()` must remain unchanged.

**Scope:**

All code paths that do NOT involve:
1. The `else` branch in `ThemeModeNotifier.load()` when `modeStr` is `null`, or
2. `Permission.sms.request()` inside `requestSmsPermission()`

…must be completely unaffected by this fix.

---

## Hypothesized Root Cause

### Bug 1 — Default Theme

1. **Wrong fallback value**: The `else` branch in `load()` writes `state = ThemeMode.system` instead of `ThemeMode.light`. The developer likely intended the fallback to mirror a light default but accidentally wrote `ThemeMode.system`.
2. **Matching constructor seed**: The constructor seed `super(ThemeMode.system)` means the UI briefly shows system-mode on startup even before `load()` completes, which may have masked the wrong fallback during testing.

### Bug 2 — SMS Permission Crash

1. **No error handling in `requestSmsPermission`**: `Permission.sms.request()` can throw a `PlatformException` on Android (e.g., manifest missing `READ_SMS`, OEM restrictions, or permanently denied state that bypasses the dialog). No `try/catch` means any thrown exception propagates to the caller.
2. **`VoidCallback` hides the async exception**: `_buildPermissionTile` accepts `onRequest: VoidCallback`. The lambda `() => PermissionService.requestSmsPermission()` fires the Future but discards it. An uncaught async exception surfaces as an unhandled Future error in Flutter's error zone, which can crash the app or cause a freeze depending on the Flutter error handler configuration.
3. **SMS treated as required**: The current structure doesn't distinguish between optional (SMS) and required permissions — any permission failure on the Allow button is potentially fatal.

---

## Correctness Properties

Property 1: Bug Condition — Default Theme Is Light on First Launch

_For any_ app launch where no theme preference has been persisted (`prefThemeMode` key is absent from `SharedPreferences`), the fixed `ThemeModeNotifier.load()` SHALL set `state` to `ThemeMode.light`, ensuring the app renders in light mode by default.

**Validates: Requirements 2.1, 2.2**

Property 2: Bug Condition — SMS Permission Errors Do Not Crash Onboarding

_For any_ invocation of `PermissionService.requestSmsPermission()` where `Permission.sms.request()` throws any exception (PlatformException or otherwise), the fixed function SHALL catch the exception and return `false`, leaving the onboarding screen functional and allowing the "Get Started" button to complete navigation.

**Validates: Requirements 2.3, 2.4**

Property 3: Preservation — Explicit Theme Preferences Are Respected

_For any_ app launch where `prefThemeMode` is `'light'` or `'dark'`, the fixed `ThemeModeNotifier.load()` SHALL produce the same `ThemeMode` as the original function, preserving all existing user theme preferences.

**Validates: Requirements 3.1, 3.2**

Property 4: Preservation — Non-SMS Permission Requests Are Unaffected

_For any_ invocation of `requestLocationPermission()`, `requestCameraPermission()`, or `requestNotificationPermission()`, the fixed code SHALL produce exactly the same behavior as the original code, preserving all existing permission request flows.

**Validates: Requirements 3.3, 3.4**

---

## Fix Implementation

### Changes Required

#### Bug 1 — Default Theme

**File**: `lib/presentation/providers/settings_providers.dart`

**Function**: `ThemeModeNotifier.load()`

**Specific Changes:**

1. **Fix fallback in `load()`**: Change the `else` branch from `state = ThemeMode.system` to `state = ThemeMode.light`.
   - Before: `} else { state = ThemeMode.system; }`
   - After: `} else { state = ThemeMode.light; }`

2. **Fix constructor seed** (optional, for consistency): Change `super(ThemeMode.system)` to `super(ThemeMode.light)` so the initial render before `load()` completes also uses light mode.
   - Before: `ThemeModeNotifier() : super(ThemeMode.system) {`
   - After: `ThemeModeNotifier() : super(ThemeMode.light) {`

---

#### Bug 2 — SMS Permission Crash

**File**: `lib/core/permissions/permission_service.dart`

**Function**: `PermissionService.requestSmsPermission()`

**Specific Changes:**

1. **Wrap in try/catch**: Surround `Permission.sms.request()` with a `try/catch` that catches all exceptions and returns `false`.
   ```dart
   static Future<bool> requestSmsPermission() async {
     try {
       final status = await Permission.sms.request();
       return status.isGranted;
     } catch (_) {
       return false;
     }
   }
   ```

No changes needed to `onboarding_screen.dart` for the crash fix — the `VoidCallback` pattern is acceptable once the callee is safe. The "Get Started" button already calls `_completeOnboarding()` directly, not `requestSmsPermission()`, so navigation is unblocked regardless.

---

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate each bug on unfixed code, then verify the fixes work correctly and preserve existing behavior.

---

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate each bug BEFORE implementing the fix. Confirm or refute the root cause analysis.

**Test Plan**: Write unit tests that simulate the exact bug conditions — empty `SharedPreferences` for the theme bug, and a throwing `Permission.sms.request()` mock for the crash bug — and run them against the UNFIXED code to observe failures.

**Test Cases:**

1. **Theme Default Test**: Create `ThemeModeNotifier` with empty `SharedPreferences` (no `prefThemeMode` key). Assert that `state == ThemeMode.light`. Will fail on unfixed code (returns `ThemeMode.system`).
2. **SMS Throw Test**: Mock `Permission.sms.request()` to throw a `PlatformException`. Assert that `requestSmsPermission()` returns `false` without rethrowing. Will fail on unfixed code (exception propagates).
3. **SMS Permanently Denied Test**: Mock `Permission.sms` status as `permanentlyDenied` and request throws. Assert graceful `false` return. Will fail on unfixed code.
4. **Onboarding Completion with SMS Error**: Simulate tapping "Get Started" after SMS permission throws. Assert navigation to `MainNavigationScreen` completes. Will fail/freeze on unfixed code.

**Expected Counterexamples:**

- `ThemeModeNotifier.state` equals `ThemeMode.system` instead of `ThemeMode.light` on first launch.
- `requestSmsPermission()` propagates exception instead of returning `false`.

---

### Fix Checking

**Goal**: Verify that for all inputs where the bug conditions hold, the fixed functions produce the expected behavior.

**Pseudocode:**

```
FOR ALL prefs WHERE isBugCondition_Theme(prefs) DO
  notifier := ThemeModeNotifier_fixed(prefs)
  ASSERT notifier.state == ThemeMode.light
END FOR

FOR ALL event WHERE isBugCondition_Sms(event) DO
  result := requestSmsPermission_fixed()  -- where sms.request() throws
  ASSERT result == false
  ASSERT no exception propagated
END FOR
```

---

### Preservation Checking

**Goal**: Verify that for all inputs where the bug conditions do NOT hold, the fixed functions produce the same result as the original functions.

**Pseudocode:**

```
FOR ALL prefs WHERE NOT isBugCondition_Theme(prefs) DO  -- prefs has 'light' or 'dark'
  ASSERT ThemeModeNotifier_original(prefs).state == ThemeModeNotifier_fixed(prefs).state
END FOR

FOR ALL permissionType WHERE permissionType != SMS DO
  ASSERT originalService.request(permissionType) == fixedService.request(permissionType)
END FOR
```

**Testing Approach**: Property-based testing is recommended for the theme preservation check because it can generate many combinations of saved preference strings, including edge values, and verify the load logic is unchanged. Unit tests suffice for the permission preservation check since there are exactly three other permission types.

**Test Cases:**

1. **Theme Saved As Light Preservation**: Load notifier with `prefThemeMode = 'light'` → assert `ThemeMode.light` (same before and after fix).
2. **Theme Saved As Dark Preservation**: Load notifier with `prefThemeMode = 'dark'` → assert `ThemeMode.dark` (unchanged).
3. **Theme Unknown String Preservation**: Load notifier with `prefThemeMode = 'oled'` (unrecognized) → assert `ThemeMode.light` after fix (was `ThemeMode.system` before; acceptable behavior change for unrecognized values, since the fallback is being intentionally changed).
4. **Location Permission Preservation**: Assert `requestLocationPermission()` behavior is identical to original.
5. **Camera Permission Preservation**: Assert `requestCameraPermission()` behavior is identical to original.
6. **Notification Permission Preservation**: Assert `requestNotificationPermission()` behavior is identical to original.

---

### Unit Tests

- Test `ThemeModeNotifier.load()` with no saved preference → expects `ThemeMode.light`.
- Test `ThemeModeNotifier.load()` with `'light'` saved → expects `ThemeMode.light`.
- Test `ThemeModeNotifier.load()` with `'dark'` saved → expects `ThemeMode.dark`.
- Test `ThemeModeNotifier.setThemeMode(ThemeMode.dark)` persists `'dark'` to prefs.
- Test `requestSmsPermission()` when `sms.request()` throws `PlatformException` → expects `false`.
- Test `requestSmsPermission()` when `sms.request()` returns `granted` → expects `true`.
- Test `requestSmsPermission()` when `sms.request()` returns `denied` → expects `false`.

### Property-Based Tests

- Generate random non-null, non-`'light'`/`'dark'` strings as `prefThemeMode` values; verify the fixed notifier always falls back to `ThemeMode.light`.
- Generate random `ThemeMode` values and verify `setThemeMode` round-trips correctly through `load()`.
- Generate random exception types thrown by `Permission.sms.request()`; verify `requestSmsPermission()` always returns `false` and never rethrows.

### Integration Tests

- Full onboarding flow on a fresh app state: verify default theme is light when entering the main screen.
- Onboarding flow with SMS permission denied mid-flow: verify "Get Started" still navigates successfully.
- Theme toggle in settings after onboarding: verify dark/light toggle persists and reloads correctly.
- Verify other permission tiles (location, camera) still invoke their respective `requestXPermission()` methods correctly during onboarding.
