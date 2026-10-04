// Preservation Property Tests — Task 2
//
// Property 4: Preservation — Non-SMS Permission Requests and Exception-Free
//             SMS Outcomes Are Unchanged
//   Validates: Requirements 3.4, 3.5, 3.6
//
// PURPOSE: Establish baseline behavior of PermissionService on UNFIXED code for
// inputs that are NOT in the bug condition domain:
//   - Exception-free SMS outcomes (granted, denied, permanentlyDenied)
//   - All Location, Camera, and Notification requests
//
// These tests MUST PASS on UNFIXED code. They confirm the behaviors we need to
// preserve through the SMS try/catch fix. The fix only adds error handling — it
// must not alter any of these code paths.
//
// OBSERVATION-FIRST METHODOLOGY (observed on UNFIXED code):
//   - requestSmsPermission() when sms.request() → granted       → true
//   - requestSmsPermission() when sms.request() → denied        → false
//   - requestSmsPermission() when sms.request() → permanentlyDenied → false
//   - requestLocationPermission()   — delegates to locationWhenInUse.request()
//   - requestCameraPermission()     — delegates to camera.request()
//   - requestNotificationPermission() — delegates to notification.request()

import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:mykhata/core/permissions/permission_service.dart';

// ---------------------------------------------------------------------------
// Fake PermissionHandlerPlatform
//
// Replaces the MethodChannel-based implementation so tests run without a
// native host. Callers configure [responses] before each test.
// ---------------------------------------------------------------------------
class _FakePermissionHandler extends PermissionHandlerPlatform {
  /// Maps a [Permission] to the [PermissionStatus] it should return from
  /// requestPermissions().
  final Map<Permission, PermissionStatus> responses;

  /// If non-null, requestPermissions() throws this object instead of returning.
  final Object? throwOnRequest;

  _FakePermissionHandler({
    required this.responses,
  }) : throwOnRequest = null;

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async {
    return responses[permission] ?? PermissionStatus.denied;
  }

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    if (throwOnRequest != null) {
      throw throwOnRequest!;
    }
    return {
      for (final p in permissions) p: responses[p] ?? PermissionStatus.denied,
    };
  }

  @override
  Future<bool> openAppSettings() async => false;

  @override
  Future<ServiceStatus> checkServiceStatus(Permission permission) async =>
      ServiceStatus.enabled;

  @override
  Future<bool> shouldShowRequestPermissionRationale(
    Permission permission,
  ) async =>
      false;
}

// ---------------------------------------------------------------------------
// Helper: install a fake handler and restore the real one in tearDown.
// We cannot easily restore the real handler because PermissionHandlerPlatform
// uses a token-guarded setter. We simply set a new fake before each test.
// ---------------------------------------------------------------------------
void _useFake(_FakePermissionHandler fake) {
  PermissionHandlerPlatform.instance = fake;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Start each test with a neutral fake to avoid cross-test contamination.
    _useFake(_FakePermissionHandler(responses: {}));
  });

  // ---------------------------------------------------------------------------
  // Unit & Property tests — exception-free SMS permission outcomes
  //
  // Validates: Requirement 3.4
  // On UNFIXED code these paths work correctly (no try/catch needed for
  // non-throwing invocations). The fix must leave them unchanged.
  // ---------------------------------------------------------------------------
  group(
    'Property 4a — Preservation: Exception-Free SMS Outcomes Are Unchanged '
    '(Validates: Requirement 3.4)',
    () {
      // The preservation domain for SMS: outcomes that do NOT throw.
      const smsPreservationCases = <(PermissionStatus, bool)>[
        (PermissionStatus.granted, true),
        (PermissionStatus.denied, false),
        (PermissionStatus.permanentlyDenied, false),
      ];

      for (final (status, expected) in smsPreservationCases) {
        test(
          'requestSmsPermission() when SMS status is ${status.name} '
          '→ returns $expected',
          () async {
            _useFake(
              _FakePermissionHandler(
                responses: {Permission.sms: status},
              ),
            );

            final result = await PermissionService.requestSmsPermission();

            // Preservation property: exception-free SMS outcomes must produce
            // the same result before and after the fix.
            expect(
              result,
              equals(expected),
              reason:
                  'Preservation: requestSmsPermission() with SMS status '
                  '${status.name} must return $expected. '
                  'The try/catch fix must not change this behavior.',
            );
          },
        );
      }
    },
  );

  // ---------------------------------------------------------------------------
  // Unit tests — Location permission is unaffected
  //
  // Validates: Requirement 3.5
  // ---------------------------------------------------------------------------
  group(
    'Preservation Unit Tests — Location Permission Is Completely Unaffected '
    '(Validates: Requirement 3.5)',
    () {
      test(
        'requestLocationPermission() returns true when locationWhenInUse is granted',
        () async {
          _useFake(
            _FakePermissionHandler(
              responses: {Permission.locationWhenInUse: PermissionStatus.granted},
            ),
          );

          final result = await PermissionService.requestLocationPermission();

          expect(
            result,
            isTrue,
            reason:
                'Preservation: requestLocationPermission() must return true '
                'when the platform grants locationWhenInUse. The SMS fix must '
                'leave this behavior completely unaffected.',
          );
        },
      );

      test(
        'requestLocationPermission() returns false when locationWhenInUse is denied',
        () async {
          _useFake(
            _FakePermissionHandler(
              responses: {
                Permission.locationWhenInUse: PermissionStatus.denied,
              },
            ),
          );

          final result = await PermissionService.requestLocationPermission();

          expect(
            result,
            isFalse,
            reason:
                'Preservation: requestLocationPermission() must return false '
                'when the platform denies locationWhenInUse.',
          );
        },
      );
    },
  );

  // ---------------------------------------------------------------------------
  // Unit tests — Camera permission is unaffected
  //
  // Validates: Requirement 3.5 (camera & storage)
  // ---------------------------------------------------------------------------
  group(
    'Preservation Unit Tests — Camera Permission Is Completely Unaffected '
    '(Validates: Requirement 3.5)',
    () {
      test(
        'requestCameraPermission() returns true when camera is granted',
        () async {
          _useFake(
            _FakePermissionHandler(
              responses: {Permission.camera: PermissionStatus.granted},
            ),
          );

          final result = await PermissionService.requestCameraPermission();

          expect(
            result,
            isTrue,
            reason:
                'Preservation: requestCameraPermission() must return true when '
                'the platform grants camera. The SMS fix must leave this '
                'behavior completely unaffected.',
          );
        },
      );

      test(
        'requestCameraPermission() returns false when camera is denied',
        () async {
          _useFake(
            _FakePermissionHandler(
              responses: {Permission.camera: PermissionStatus.denied},
            ),
          );

          final result = await PermissionService.requestCameraPermission();

          expect(
            result,
            isFalse,
            reason:
                'Preservation: requestCameraPermission() must return false when '
                'the platform denies camera.',
          );
        },
      );
    },
  );

  // ---------------------------------------------------------------------------
  // Unit tests — Notification permission is unaffected
  //
  // Validates: Requirement 3.6
  // ---------------------------------------------------------------------------
  group(
    'Preservation Unit Tests — Notification Permission Is Completely Unaffected '
    '(Validates: Requirement 3.6)',
    () {
      test(
        'requestNotificationPermission() returns true when notification is granted',
        () async {
          _useFake(
            _FakePermissionHandler(
              responses: {
                Permission.notification: PermissionStatus.granted,
              },
            ),
          );

          final result =
              await PermissionService.requestNotificationPermission();

          expect(
            result,
            isTrue,
            reason:
                'Preservation: requestNotificationPermission() must return true '
                'when the platform grants notification. The SMS fix must leave '
                'this behavior completely unaffected.',
          );
        },
      );

      test(
        'requestNotificationPermission() returns false when notification is denied',
        () async {
          _useFake(
            _FakePermissionHandler(
              responses: {
                Permission.notification: PermissionStatus.denied,
              },
            ),
          );

          final result =
              await PermissionService.requestNotificationPermission();

          expect(
            result,
            isFalse,
            reason:
                'Preservation: requestNotificationPermission() must return false '
                'when the platform denies notification.',
          );
        },
      );
    },
  );

  // ---------------------------------------------------------------------------
  // Property-based test — Non-SMS permissions are structurally unaffected
  //
  // For all (permission, status) combinations outside the SMS / bug domain,
  // the corresponding requestXPermission() function returns status.isGranted.
  // This is the universal structural property of the three unaffected helpers.
  //
  // Validates: Requirements 3.5, 3.6
  // ---------------------------------------------------------------------------
  group(
    'Property 4b — Preservation: Non-SMS requestXPermission() Returns '
    'status.isGranted for All Non-Throwing Statuses '
    '(Validates: Requirements 3.5, 3.6)',
    () {
      // All non-throwing PermissionStatus values in the preservation domain.
      const nonThrowingStatuses = [
        PermissionStatus.granted,
        PermissionStatus.denied,
        PermissionStatus.permanentlyDenied,
        PermissionStatus.restricted,
        PermissionStatus.limited,
      ];

      // The three unaffected permissions with their request helpers.
      final unaffectedPermissions = <
          (
            String,
            Permission,
            Future<bool> Function(),
          )>[
        (
          'location',
          Permission.locationWhenInUse,
          () => PermissionService.requestLocationPermission(),
        ),
        (
          'camera',
          Permission.camera,
          () => PermissionService.requestCameraPermission(),
        ),
        (
          'notification',
          Permission.notification,
          () => PermissionService.requestNotificationPermission(),
        ),
      ];

      for (final (name, permission, requestFn) in unaffectedPermissions) {
        for (final status in nonThrowingStatuses) {
          test(
            'request${name[0].toUpperCase()}${name.substring(1)}Permission() '
            'with $name=${status.name} → returns ${status.isGranted}',
            () async {
              _useFake(
                _FakePermissionHandler(responses: {permission: status}),
              );

              final result = await requestFn();

              // Structural property: result == status.isGranted for all
              // non-throwing statuses and all non-SMS permission helpers.
              expect(
                result,
                equals(status.isGranted),
                reason:
                    'Preservation property: request${name}Permission() with '
                    'status=${status.name} must return ${status.isGranted} '
                    '(== status.isGranted). The SMS fix must never change this.',
              );
            },
          );
        }
      }
    },
  );

  // ---------------------------------------------------------------------------
  // Observation: checkAllPermissions() aggregates all four permissions
  // (smoke test — structural preservation of the map shape)
  // ---------------------------------------------------------------------------
  group('Preservation Smoke Test — checkAllPermissions() shape is unchanged', () {
    test(
      'checkAllPermissions() returns a map with exactly the four expected keys',
      () async {
        _useFake(
          _FakePermissionHandler(
            responses: {
              Permission.sms: PermissionStatus.granted,
              Permission.locationWhenInUse: PermissionStatus.granted,
              Permission.camera: PermissionStatus.denied,
              Permission.notification: PermissionStatus.denied,
            },
          ),
        );

        final result = await PermissionService.checkAllPermissions();

        expect(
          result.keys.toSet(),
          equals({'sms', 'location', 'camera', 'notification'}),
          reason:
              'checkAllPermissions() must always return a map with the four '
              'keys: sms, location, camera, notification.',
        );
        expect(result['sms'], isTrue);
        expect(result['location'], isTrue);
        expect(result['camera'], isFalse);
        expect(result['notification'], isFalse);
      },
    );
  });
}
