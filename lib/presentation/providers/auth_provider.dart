import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/security/auth_service.dart';

final authServiceProvider = Provider((ref) => AuthService());

class AuthState {
  final bool isUnlocked;
  final bool isBiometricsEnabled;

  AuthState({
    required this.isUnlocked,
    required this.isBiometricsEnabled,
  });

  AuthState copyWith({
    bool? isUnlocked,
    bool? isBiometricsEnabled,
  }) {
    return AuthState(
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isBiometricsEnabled: isBiometricsEnabled ?? this.isBiometricsEnabled,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  bool _isAuthenticating = false;

  AuthNotifier(this._authService)
      : super(AuthState(isUnlocked: true, isBiometricsEnabled: false)) {
    _init();
  }

  Future<void> _init() async {
    final enabled = await _authService.isBiometricsEnabled();
    if (enabled) {
      state = state.copyWith(
        isBiometricsEnabled: true,
        isUnlocked: false,
      );
      // Immediately trigger biometric prompt on cold startup
      authenticate();
    } else {
      state = state.copyWith(
        isBiometricsEnabled: false,
        isUnlocked: true,
      );
    }
  }

  Future<bool> authenticate({String? reason}) async {
    if (!state.isBiometricsEnabled) {
      state = state.copyWith(isUnlocked: true);
      return true;
    }

    if (_isAuthenticating) return false;
    _isAuthenticating = true;

    try {
      final success = await _authService.authenticate(
        reason: reason ?? 'Please authenticate to access MyKhata',
      );
      if (success) {
        state = state.copyWith(isUnlocked: true);
      }
      return success;
    } finally {
      _isAuthenticating = false;
    }
  }

  void lock() {
    if (state.isBiometricsEnabled) {
      state = state.copyWith(isUnlocked: false);
    }
  }

  void handleAppLifecycleState(AppLifecycleState lifecycleState) {
    if (!state.isBiometricsEnabled) return;

    if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.hidden) {
      state = state.copyWith(isUnlocked: false);
    } else if (lifecycleState == AppLifecycleState.resumed) {
      if (!state.isUnlocked) {
        authenticate();
      }
    }
  }

  Future<bool> toggleBiometrics(bool enabled) async {
    if (enabled) {
      final canAuth = await _authService.canAuthenticate();
      if (!canAuth) {
        return false;
      }
      final success = await _authService.authenticate(
        reason: 'Authenticate to enable biometric protection',
      );
      if (!success) {
        return false;
      }
    }
    await _authService.setBiometricsEnabled(enabled);
    state = state.copyWith(
      isBiometricsEnabled: enabled,
      isUnlocked: true,
    );
    return true;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final service = ref.watch(authServiceProvider);
  return AuthNotifier(service);
});
