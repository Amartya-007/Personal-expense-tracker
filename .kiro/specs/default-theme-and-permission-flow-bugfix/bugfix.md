# Bugfix Requirements Document

## Introduction

The MyKhata Flutter app has two related bugs. First, the app defaults to the system theme instead of the light theme, causing inconsistent appearance on devices where the system theme is dark. Second, the onboarding permissions screen crashes or freezes when the user taps "Get Started" after SMS permission is denied — this is because the SMS permission request can hang or throw an unhandled error on devices where SMS permission is unavailable (e.g., the app is not set as the default SMS app), and the permission flow has no graceful handling for denial. Together, these bugs prevent users from completing onboarding successfully.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN the app is launched for the first time with no saved theme preference THEN the system applies `ThemeMode.system`, which follows the device's OS theme and may show a dark theme

1.2 WHEN the app is launched and the device OS theme is dark THEN the app displays in dark mode instead of the expected light theme default

1.3 WHEN the user reaches the permissions screen during onboarding and taps "Allow" for SMS Detection on a device that cannot grant SMS permission (e.g., app is not the default SMS app, or the Android version restricts SMS access) THEN the SMS permission request either hangs indefinitely, throws an unhandled exception, or returns a permanently-denied status with no user feedback

1.4 WHEN the user taps "Get Started" after SMS permission has been denied and other permissions (Location, Camera) have been granted THEN the app crashes, freezes, or fails to navigate to the main screen

1.5 WHEN the app is in a crashed or frozen state after SMS denial THEN the user cannot proceed to the main screen and must force-close the app

### Expected Behavior (Correct)

2.1 WHEN the app is launched for the first time with no saved theme preference THEN the system SHALL apply `ThemeMode.light` as the default, showing the light theme regardless of the device OS theme

2.2 WHEN the app is launched and no theme preference has been explicitly saved by the user THEN the app SHALL display in light mode

2.3 WHEN the user taps "Allow" for SMS Detection and the device cannot grant SMS permission THEN the system SHALL handle the denial gracefully, update the SMS permission tile to reflect the denied state, and allow the user to continue

2.4 WHEN the user taps "Get Started" after SMS permission has been denied (but other permissions may or may not be granted) THEN the system SHALL successfully complete onboarding and navigate to the main screen

2.5 WHEN SMS permission is permanently denied or unavailable on the device THEN the system SHALL treat SMS as an optional permission and SHALL NOT block the onboarding completion flow

### Unchanged Behavior (Regression Prevention)

3.1 WHEN the user has previously saved a theme preference of "dark" THEN the system SHALL CONTINUE TO display the app in dark mode on subsequent launches

3.2 WHEN the user has previously saved a theme preference of "light" THEN the system SHALL CONTINUE TO display the app in light mode on subsequent launches

3.3 WHEN the user has previously saved a theme preference of "system" THEN the system SHALL CONTINUE TO follow the OS theme

3.4 WHEN the user taps "Allow" for SMS Detection and the device successfully grants SMS permission THEN the system SHALL CONTINUE TO record the granted status and enable SMS-based transaction detection

3.5 WHEN the user taps "Allow" for Location permission and the device grants it THEN the system SHALL CONTINUE TO record the granted status and use location when adding expenses

3.6 WHEN the user taps "Allow" for Camera & Storage permission and the device grants it THEN the system SHALL CONTINUE TO record the granted status and allow receipt photo attachments

3.7 WHEN the user completes the onboarding account setup step and taps "Next" THEN the system SHALL CONTINUE TO navigate to the permissions step

3.8 WHEN the user completes onboarding successfully THEN the system SHALL CONTINUE TO save the onboarding-complete flag and navigate to the main screen

---

## Bug Condition Pseudocode

### Bug 1: Default Theme

```pascal
FUNCTION isBugCondition_DefaultTheme(X)
  INPUT: X of type AppLaunchContext
  OUTPUT: boolean

  // Bug triggers when no theme preference has been saved
  RETURN X.savedThemePreference = null OR X.savedThemePreference = 'system'
END FUNCTION

// Property: Fix Checking
FOR ALL X WHERE isBugCondition_DefaultTheme(X) DO
  result ← getInitialThemeMode'(X)
  ASSERT result = ThemeMode.light
END FOR

// Property: Preservation Checking
FOR ALL X WHERE NOT isBugCondition_DefaultTheme(X) DO
  ASSERT getInitialThemeMode(X) = getInitialThemeMode'(X)
END FOR
```

### Bug 2: SMS Permission Crash on Get Started

```pascal
FUNCTION isBugCondition_SmsPermission(X)
  INPUT: X of type PermissionFlowContext
  OUTPUT: boolean

  // Bug triggers when SMS permission is denied/unavailable and user presses Get Started
  RETURN X.smsPermissionStatus = denied OR X.smsPermissionStatus = permanentlyDenied OR X.smsPermissionStatus = restricted
END FUNCTION

// Property: Fix Checking
FOR ALL X WHERE isBugCondition_SmsPermission(X) DO
  result ← completeOnboarding'(X)
  ASSERT result.navigatedToMainScreen = true AND result.noCrash = true
END FOR

// Property: Preservation Checking
FOR ALL X WHERE NOT isBugCondition_SmsPermission(X) DO
  ASSERT completeOnboarding(X) = completeOnboarding'(X)
END FOR
```
