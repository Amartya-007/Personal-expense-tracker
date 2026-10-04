import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_constants.dart';
import 'core/logging/app_logger.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/settings_providers.dart';
import 'presentation/providers/sms_review_providers.dart';
import 'presentation/screens/lock/lock_screen.dart';
import 'presentation/screens/main/main_navigation_screen.dart';
import 'presentation/screens/onboarding/onboarding_screen.dart';
import 'services/notifications/notification_service.dart';
import 'services/sms/sms_parser_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    AppLogger.e(
      'Flutter framework error: ${details.exceptionAsString()}',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  await runZonedGuarded(
    () async {
      try {
        await NotificationService.init();
      } catch (e, st) {
        await AppLogger.e(
          'NotificationService.init failed',
          error: e,
          stackTrace: st,
        );
      }

      final prefs = await SharedPreferences.getInstance();
      final bool isOnboardingComplete =
          prefs.getBool(AppConstants.prefIsOnboardingComplete) ?? false;

      runApp(
        ProviderScope(
          child: MyKhataApp(isOnboardingComplete: isOnboardingComplete),
        ),
      );
    },
    (error, stack) {
      AppLogger.e('Uncaught async error', error: error, stackTrace: stack);
    },
  );
}

class MyKhataApp extends ConsumerStatefulWidget {
  final bool isOnboardingComplete;

  const MyKhataApp({super.key, required this.isOnboardingComplete});

  @override
  ConsumerState<MyKhataApp> createState() => _MyKhataAppState();
}

class _MyKhataAppState extends ConsumerState<MyKhataApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(authProvider.notifier).handleAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      SmsParserService().processPendingMessages().then((count) {
        if (count > 0) {
          ref.invalidate(smsQueueProvider('detected'));
        }
      }).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: widget.isOnboardingComplete
          ? const AuthGuard()
          : const OnboardingScreen(),
    );
  }
}

class AuthGuard extends ConsumerWidget {
  const AuthGuard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    if (!authState.isUnlocked) {
      return const LockScreen();
    }
    return const MainNavigationScreen();
  }
}
