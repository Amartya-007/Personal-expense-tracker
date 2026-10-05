import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/account_model.dart';
import '../../providers/account_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/list_widgets.dart';
import '../../widgets/pressable.dart';
import '../../widgets/primary_button.dart';
import '../main/main_navigation_screen.dart';

/// Steps: 0 welcome, 1 you + first account, 2 permissions, 3 security, 4 done.
/// (Used to be 8 steps: three separate marketing slides, which are now a
/// single compact list on the welcome step.)
const int _lastStep = 4;

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  bool _forward = true;

  // No pre-filled "SBI / 50000": fake defaults used to be saved silently.
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();
  final FocusNode _accountNameFocusNode = FocusNode();
  final Uuid _uuid = const Uuid();

  final List<AccountModel> _queuedAccounts = [];
  String? _accountError;

  bool _notifEnabled = true;
  bool _locEnabled = true;
  bool _camEnabled = true;
  bool _smsEnabled = true;
  bool _requestingPermissions = false;

  bool _biometricSuccess = false;
  bool _finishing = false;

  @override
  void dispose() {
    _nameController.dispose();
    _accountNameController.dispose();
    _balanceController.dispose();
    _accountNameFocusNode.dispose();
    super.dispose();
  }

  void _go(int step) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _forward = step > _step;
      _step = step.clamp(0, _lastStep);
    });
  }

  void _next() => _go(_step + 1);

  void _back() => _go(_step - 1);

  AccountModel? _accountFromFields() {
    final name = _accountNameController.text.trim();
    if (name.isEmpty) return null;
    final balance = double.tryParse(_balanceController.text.trim()) ?? 0.0;
    final now = DateTime.now();
    return AccountModel(
      id: _uuid.v4(),
      name: name,
      currentBalance: balance,
      initialBalance: balance,
      createdAt: now,
      updatedAt: now,
    );
  }

  void _addAnotherAccount() {
    final acc = _accountFromFields();
    if (acc == null) {
      setState(() => _accountError = 'Enter an account name first.');
      return;
    }
    setState(() {
      _queuedAccounts.add(acc);
      _accountNameController.clear();
      _balanceController.clear();
      _accountError = null;
    });
    _accountNameFocusNode.requestFocus();
  }

  void _continueFromAccount() {
    // Include whatever is typed in the fields, even if accounts are already
    // queued (it used to be dropped in that case).
    if (_accountNameController.text.trim().isEmpty && _queuedAccounts.isEmpty) {
      setState(() => _accountError = 'Add at least one account to continue.');
      return;
    }
    _next();
  }

  Future<void> _continueFromPermissions() async {
    setState(() => _requestingPermissions = true);
    // "Allow selected" now actually asks for each selected permission (it used
    // to only ask when a switch was toggled), and records what was granted.
    try {
      if (_notifEnabled) {
        await PermissionService.requestNotificationPermission();
      }
      if (_locEnabled) {
        _locEnabled = await PermissionService.requestLocationPermission();
      }
      if (_camEnabled) {
        await PermissionService.requestCameraPermission();
      }
      if (_smsEnabled) {
        _smsEnabled = await PermissionService.requestSmsPermission();
      }
    } catch (_) {
      // A failed prompt must never block onboarding.
    }
    if (!mounted) return;
    setState(() => _requestingPermissions = false);
    _next();
  }

  void _skipPermissions() {
    setState(() {
      _notifEnabled = false;
      _locEnabled = false;
      _camEnabled = false;
      _smsEnabled = false;
    });
    _next();
  }

  Future<void> _enableBiometrics() async {
    final ok = await ref.read(authProvider.notifier).toggleBiometrics(true);
    if (!mounted) return;
    if (!ok) {
      // It used to show a green tick and move on even when this failed.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not turn on biometric lock. Set up a fingerprint, face or screen lock in Android Settings, or try again later in Settings.',
          ),
        ),
      );
      return;
    }
    setState(() => _biometricSuccess = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _next();
  }

  Future<void> _completeOnboarding() async {
    if (_finishing) return;
    setState(() => _finishing = true);

    try {
      final typed = _accountFromFields();
      final accounts = <AccountModel>[
        ..._queuedAccounts,
        if (typed != null) typed,
      ];

      for (final acc in accounts) {
        await ref.read(accountListProvider.notifier).createAccount(acc);
      }

      final name = _nameController.text.trim();
      if (name.isNotEmpty) {
        await ref.read(userNameProvider.notifier).setUserName(name);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.prefAutoSmsDetection, _smsEnabled);
      await prefs.setBool(AppConstants.prefAutoLocationCapture, _locEnabled);
      await prefs.setBool(AppConstants.prefIsOnboardingComplete, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _finishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not finish setup: $e')),
      );
      return;
    }

    if (!mounted) return;
    // Keep the in-memory preference providers in step with what was saved.
    ref.read(autoSmsDetectionProvider.notifier).set(_smsEnabled);
    ref.read(autoLocationCaptureProvider.notifier).set(_locEnabled);
    AppRoutes.fadeReplace<dynamic, dynamic>(
      context,
      const MainNavigationScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0 && _step < _lastStep) _back();
      },
      child: Scaffold(
        backgroundColor: p.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(p),
              Expanded(
                child: AnimatedSwitcher(
                  duration: AppMotion.medium,
                  switchInCurve: AppMotion.enter,
                  switchOutCurve: AppMotion.exit,
                  layoutBuilder: (current, previous) => Stack(
                    fit: StackFit.expand,
                    children: [...previous, if (current != null) current],
                  ),
                  transitionBuilder: (child, animation) {
                    final incoming = child.key == ValueKey<int>(_step);
                    final d = _forward ? 0.12 : -0.12;
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: Offset(incoming ? d : -d, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(_step),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                      child: _buildStep(p),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(AppPalette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 20, 6),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: (_step > 0 && _step < _lastStep)
                ? TextButton(
                    onPressed: _back,
                    style: TextButton.styleFrom(foregroundColor: p.muted),
                    child: const Text('‹ Back'),
                  )
                : null,
          ),
          Expanded(
            child: Row(
              children: [
                for (var i = 0; i <= _lastStep; i++)
                  Expanded(
                    child: AnimatedContainer(
                      duration: AppMotion.medium,
                      curve: AppMotion.standard,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i <= _step ? p.primary : p.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 56),
        ],
      ),
    );
  }

  Widget _buildStep(AppPalette p) {
    switch (_step) {
      case 0:
        return _buildWelcome(p);
      case 1:
        return _buildProfileAndAccount(p);
      case 2:
        return _buildPermissions(p);
      case 3:
        return _buildSecurity(p);
      default:
        return _buildDone(p);
    }
  }

  Widget _buildWelcome(AppPalette p) {
    Widget feature(String emoji, String title, String body) => ListRowTile(
          emoji: emoji,
          title: title,
          subtitle: body,
        );

    return Column(
      children: [
        const SizedBox(height: 24),
        FadeSlideIn(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: p.heroGradient,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: p.primary.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              '₹',
              style: TextStyle(
                fontSize: 42,
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        FadeSlideIn(
          index: 1,
          child: Text(
            'MyKhata',
            style: AppText.display(p.ink).copyWith(fontSize: 34),
          ),
        ),
        const SizedBox(height: 10),
        FadeSlideIn(
          index: 2,
          child: Text(
            'Record, understand and monitor your money with the least possible effort.',
            textAlign: TextAlign.center,
            style: AppText.caption(p.muted).copyWith(fontSize: 14, height: 1.6),
          ),
        ),
        const SizedBox(height: 28),
        FadeSlideIn(
          index: 3,
          child: SettingsGroup(
            children: [
              feature(
                '💬',
                'Bank messages, sorted for you',
                'Nothing is added until you confirm it.',
              ),
              feature(
                '🧾',
                'Receipts with the expense',
                'Photos stay on this phone.',
              ),
              feature(
                '📊',
                'Budgets that tell you early',
                'A nudge at 75%, 90% and 100%.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        FadeSlideIn(
          index: 4,
          child: PrimaryButton(label: 'Get started', onPressed: _next),
        ),
        const SizedBox(height: 14),
        Text(
          'Private · Offline · No sign-up · No ads',
          style: AppText.caption(p.muted),
        ),
      ],
    );
  }

  Widget _buildProfileAndAccount(AppPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Let’s set you up', style: AppText.display(p.ink)),
        const SizedBox(height: 8),
        Text(
          'Use the balance you have right now. You can change anything later.',
          style: AppText.caption(p.muted).copyWith(fontSize: 14),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Your name (optional)',
            hintText: 'What should we call you?',
          ),
        ),
        const SizedBox(height: 22),
        Text('FIRST BANK ACCOUNT', style: AppText.section(p.muted)),
        const SizedBox(height: 10),
        TextField(
          controller: _accountNameController,
          focusNode: _accountNameFocusNode,
          textInputAction: TextInputAction.next,
          onChanged: (_) {
            if (_accountError != null) setState(() => _accountError = null);
          },
          decoration: InputDecoration(
            labelText: 'Account name',
            hintText: 'e.g. SBI Savings',
            errorText: _accountError,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _balanceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Current balance',
            prefixText: '₹ ',
            hintText: '0',
          ),
        ),
        const SizedBox(height: 14),
        if (_queuedAccounts.isNotEmpty) ...[
          SettingsGroup(
            children: [
              for (final acc in _queuedAccounts)
                ListRowTile(
                  emoji: '🏦',
                  title: acc.name,
                  trailing: Text(
                    CurrencyFormatter.format(acc.currentBalance),
                    style: AppText.bodyStrong(p.ink),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        TextButton.icon(
          onPressed: _addAnotherAccount,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('Add another bank account'),
        ),
        const SizedBox(height: 4),
        Text(
          'Cash is a payment method in MyKhata, so you don’t need a Cash account.',
          style: AppText.caption(p.muted),
        ),
        const SizedBox(height: 26),
        PrimaryButton(label: 'Continue', onPressed: _continueFromAccount),
      ],
    );
  }

  Widget _buildPermissions(AppPalette p) {
    Widget row(
      String emoji,
      String title,
      String subtitle,
      bool value,
      ValueChanged<bool> onChanged,
    ) =>
        ListRowTile(
          emoji: emoji,
          title: title,
          subtitle: subtitle,
          trailing: Switch(
            value: value,
            activeThumbColor: p.primary,
            onChanged: onChanged,
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('A few permissions', style: AppText.display(p.ink)),
        const SizedBox(height: 8),
        Text(
          'Each one is optional. We only use them for the reason shown.',
          style: AppText.caption(p.muted).copyWith(fontSize: 14),
        ),
        const SizedBox(height: 20),
        SettingsGroup(
          children: [
            row(
              '🔔',
              'Notifications',
              'Alerts when you near a budget limit',
              _notifEnabled,
              (v) => setState(() => _notifEnabled = v),
            ),
            row(
              '📍',
              'Location',
              'Saved with an expense, only when you save',
              _locEnabled,
              (v) => setState(() => _locEnabled = v),
            ),
            row(
              '📷',
              'Camera',
              'Photograph receipts',
              _camEnabled,
              (v) => setState(() => _camEnabled = v),
            ),
            row(
              '💬',
              'SMS',
              'Detect bank messages so you can review them',
              _smsEnabled,
              (v) => setState(() => _smsEnabled = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'You can change these any time in Settings.',
          style: AppText.caption(p.muted),
        ),
        const SizedBox(height: 26),
        PrimaryButton(
          label: 'Allow selected',
          loading: _requestingPermissions,
          onPressed: _continueFromPermissions,
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: _requestingPermissions ? null : _skipPermissions,
            style: TextButton.styleFrom(foregroundColor: p.muted),
            child: const Text('Not now'),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurity(AppPalette p) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Text('Lock it down', style: AppText.display(p.ink)),
        const SizedBox(height: 8),
        Text(
          "Open MyKhata with your fingerprint or face. If that doesn't work, your phone's PIN or pattern does.",
          textAlign: TextAlign.center,
          style: AppText.caption(p.muted).copyWith(fontSize: 14, height: 1.6),
        ),
        const SizedBox(height: 44),
        Pressable(
          onTap: _enableBiometrics,
          child: AnimatedContainer(
            duration: AppMotion.medium,
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: _biometricSuccess ? p.income : p.surface2,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (_biometricSuccess ? p.income : p.primary)
                      .withValues(alpha: 0.3),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: AppMotion.fast,
              child: Text(
                _biometricSuccess ? '✓' : '👆',
                key: ValueKey(_biometricSuccess),
                style: TextStyle(
                  fontSize: 50,
                  color: _biometricSuccess ? Colors.white : null,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
        PrimaryButton(
          label: 'Enable biometric lock',
          icon: Icons.lock_rounded,
          onPressed: _enableBiometrics,
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: _next,
          style: TextButton.styleFrom(foregroundColor: p.muted),
          child: const Text('Maybe later'),
        ),
      ],
    );
  }

  Widget _buildDone(AppPalette p) {
    final name = _nameController.text.trim();

    return Column(
      children: [
        const SizedBox(height: 40),
        FadeSlideIn(
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: p.income,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: p.income.withValues(alpha: 0.35),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              '✓',
              style: TextStyle(
                fontSize: 60,
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
        FadeSlideIn(
          index: 1,
          child: Text(
            name.isEmpty ? "You're all set" : "You're all set, $name",
            textAlign: TextAlign.center,
            style: AppText.display(p.ink),
          ),
        ),
        const SizedBox(height: 12),
        FadeSlideIn(
          index: 2,
          child: Text(
            'Ready to track. Tap + whenever you spend.',
            textAlign: TextAlign.center,
            style: AppText.caption(p.muted).copyWith(fontSize: 14, height: 1.6),
          ),
        ),
        const SizedBox(height: 60),
        PrimaryButton(
          label: 'Open MyKhata',
          loading: _finishing,
          onPressed: _completeOnboarding,
        ),
      ],
    );
  }
}
