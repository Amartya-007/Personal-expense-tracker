import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Page transition used by every `MaterialPageRoute` through
/// `ThemeData.pageTransitionsTheme`: the incoming page fades and slides in
/// from the right while the page underneath drifts left slightly.
///
/// Before this existed the app used the platform default, so screens popped
/// in with no shared motion language.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final incoming = CurvedAnimation(
      parent: animation,
      curve: AppMotion.enter,
      reverseCurve: AppMotion.exit,
    );
    final outgoing = CurvedAnimation(
      parent: secondaryAnimation,
      curve: AppMotion.standard,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.06, 0),
      ).animate(outgoing),
      child: FadeTransition(
        opacity: incoming,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.08, 0),
            end: Offset.zero,
          ).animate(incoming),
          child: child,
        ),
      ),
    );
  }
}

/// Navigation helpers so screens stop hand-rolling `MaterialPageRoute`.
class AppRoutes {
  AppRoutes._();

  /// Standard push (uses the themed transition above).
  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute<T>(builder: (_) => page),
    );
  }

  /// Full-screen task flows (e.g. add transaction) rise from the bottom.
  static Future<T?> pushModal<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push<T>(_slideUp<T>(page));
  }

  /// Replace the current route with a cross-fade (onboarding -> app).
  static Future<T?> fadeReplace<T, R>(BuildContext context, Widget page) {
    return Navigator.of(context).pushReplacement<T, R>(_fade<T>(page));
  }

  /// Replace the whole navigation stack with [page] using a cross-fade (used
  /// to return to onboarding after "delete all data"). Takes the navigator
  /// itself so it can be called after awaiting.
  static Future<T?> fadeResetTo<T>(NavigatorState navigator, Widget page) {
    return navigator.pushAndRemoveUntil<T>(_fade<T>(page), (route) => false);
  }

  static Route<T> _fade<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: AppMotion.slow,
      reverseTransitionDuration: AppMotion.medium,
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );
  }

  static Route<T> _slideUp<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: AppMotion.slow,
      reverseTransitionDuration: AppMotion.medium,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: AppMotion.enter,
          reverseCurve: AppMotion.exit,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}
