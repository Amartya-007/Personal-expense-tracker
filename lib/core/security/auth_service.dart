import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../logging/app_logger.dart';

class AuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Returns true only when the device has biometrics hardware AND the user
  /// has actually enrolled at least one biometric credential.
  ///
  /// BUG FIX: the old implementation returned true for devices with hardware
  /// but no enrolled biometrics, causing silent authenticate() failures and
  /// potentially locking users out of the app.
  Future<bool> canAuthenticate() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) {
        // No biometric hardware — fall back to device PIN/pattern check.
        return await _auth.isDeviceSupported();
      }
      // Check whether the user has actually enrolled a biometric.
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBiometricsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.prefBiometricsEnabled) ?? false;
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefBiometricsEnabled, enabled);
    await AppLogger.i('Biometric setting changed to $enabled');
  }

  Future<bool> authenticate({
    String reason = 'Please authenticate to access MyKhata',
  }) async {
    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Fallback to device PIN/password/pattern
        ),
      );
      return didAuthenticate;
    } on PlatformException catch (e, stack) {
      await AppLogger.e(
        'Authentication failed with platform error',
        error: e,
        stackTrace: stack,
      );
      return false;
    } catch (e, stack) {
      await AppLogger.e('Authentication failed', error: e, stackTrace: stack);
      return false;
    }
  }
}
