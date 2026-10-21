import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/amount_input.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/text_sanitizer.dart';
import '../../../data/models/account_model.dart';
import '../../providers/account_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/list_widgets.dart';
import '../../widgets/primary_button.dart';
import '../main/main_navigation_screen.dart';
import 'widgets/onboarding_illustrations.dart';

/// Eight-step onboarding matching `MyKhata onboarding.html`, rendered in the
/// app's teal design system:
/// 0 welcome, 1 sms, 2 receipt, 3 budget, 4 add first account, 5 permissions,
/// 6 security/biometric, 7 done.
///
/// This is a drop-in replacement for the previous 5-step screen: the class
/// name, location and completion behaviour are unchanged, so `main.dart`'s
/// onboarding entry-point contract still holds. Every existing behaviour
/// (account queue, optional user name, permission requests, biometrics, finish
/// prefs/provider sync, back navigation) is preserved.
const int _lastStep = 7;

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  bool _forward = true;

  // Optional user name (collected on the welcome step — see plan D2 — so the
  // account step stays faithful to the mockup and the done greeting still
  // works). No pre-filled fake defaults.
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();
  final FocusNode _accountNameFocusNode = FocusNode();
  final Uuid _uuid = const Uuid();

  final List<AccountModel> _queuedAccounts = [];
  String? _accountError;
  String? _balanceError;

  bool _notifEnabled = true;
  bool _locEnabled = true;
  bool _camEnabled = true;
  // Photos groups with Camera (see plan D3): the app has no separate Photos
  // permission, so both toggles map onto requestCameraPermission().
  bool _photosEnabled = true;
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

  /// Whether Continue should be enabled on the account step: an account is
  /// queued OR a name is currently typed (mirrors the mockup's `chk()`).
  bool get _accountExists =>
      _queuedAccounts.isNotEmpty ||
      _accountNameController.text.trim().isNotEmpty;

  /// Balance may be left empty (= 0) but, if typed, must be a valid amount.
  String? _validateBalance(String raw) => raw.trim().isEmpty
      ? null
      : AmountInput.validateAmount(raw, allowZero: true);

  AccountModel? _accountFromFields() {
    final name = TextSanitizer.singleLine(_accountNameController.text);
    if (name.isEmpty) return null;
    final balance = AmountInput.parseAmount(_balanceController.text) ?? 0.0;
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

  /// Account names that will be created on finish (queued + whatever is typed
  /// but not yet added). Used for the done-step subtitle.
  List<String> _plannedAccountNames() {
    final names = _queuedAccounts.map((a) => a.name).toList();
    final typed = TextSanitizer.singleLine(_accountNameController.text);
    if (typed.isNotEmpty) names.add(typed);
    return names;
  }

  void _addAnotherAccount() {
    final balErr = _validateBalance(_balanceController.text);
    if (balErr != null) {
      setState(() => _balanceError = balErr);
      return;
    }
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
      _balanceError = null;
    });
    _accountNameFocusNode.requestFocus();
  }

  void _continueFromAccount() {
    // Include whatever is typed in the fields, even if accounts are already
    // queued (it used to be dropped in that case).
    final balErr = _validateBalance(_balanceController.text);
    if (balErr != null) {
      setState(() => _balanceError = balErr);
      return;
    }
    if (_accountNameController.text.trim().isEmpty && _queuedAccounts.isEmpty) {
      setState(() => _accountError = 'Add at least one account to continue.');
      return;
    }
    _next();
  }

  Future<void> _continueFromPermissions() async {
    setState(() => _requestingPermissions = true);
    // "Allow selected" asks for each selected permission and records what was
    // granted.
    try {
      if (_notifEnabled) {
        await PermissionService.requestNotificationPermission();
      }
      if (_locEnabled) {
        _locEnabled = await PermissionService.requestLocationPermission();
      }
      // Photos groups with Camera (plan D3): one camera request covers either.
      if (_camEnabled || _photosEnabled) {
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
      _photosEnabled = false;
      _smsEnabled = false;
    });
    _next();
  }

  Future<void> _enableBiometrics() async {
    if (_biometricSuccess) return;
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

      final name = TextSanitizer.singleLine(_nameController.text);
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not finish setup: $e')));
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
        // Android back goes to the previous step, except on the first step and
        // the final step (where the mockup hides Back).
        if (!didPop && _step > 0 && _step < _lastStep) _back();
      },
      child: Scaffold(
        backgroundColor: p.background,
        body: SafeArea(
          child: Column(
            children: [
              // Top bar fades out entirely on the welcome step (mockup n==0).
              AnimatedOpacity(
                duration: AppMotion.slow,
                opacity: _step == 0 ? 0 : 1,
                child: IgnorePointer(
                  ignoring: _step == 0,
                  child: _buildTopBar(p),
                ),
              ),
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
                    child: _buildStep(p),
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
    // Back hidden on step 0 and the final step; Skip only on feature steps 1–3.
    final showBack = _step > 0 && _step < _lastStep;
    final showSkip = _step > 0 && _step < 4;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 20, 6),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: showBack
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
                      duration: AppMotion.slow,
                      curve: AppMotion.emphasized,
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
          SizedBox(
            width: 56,
            child: showSkip
                ? TextButton(
                    onPressed: _next,
                    style: TextButton.styleFrom(foregroundColor: p.muted),
                    child: const Text('Skip'),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStep(AppPalette p) {
    switch (_step) {
      case 0:
        return _buildWelcome(p);
      case 1:
        return _buildFeature(
          p,
          art: const OnbSmsArt(),
          title: 'Bank messages, sorted for you',
          subtitle:
              'MyKhata spots transaction SMS and lines them up for review. '
              'Nothing is added until you confirm it.',
        );
      case 2:
        return _buildFeature(
          p,
          art: const OnbReceiptArt(),
          title: 'Keep receipts with the expense',
          subtitle:
              'Snap or attach receipts. They stay on this phone, next to the '
              'expense they belong to.',
        );
      case 3:
        return _buildFeature(
          p,
          art: const OnbBudgetArt(),
          title: 'Budgets that tell you early',
          subtitle:
              'Set a limit, then get a nudge at 75%, 90% and 100%. Once per '
              'period, never spam.',
        );
      case 4:
        return _buildAccount(p);
      case 5:
        return _buildPermissions(p);
      case 6:
        return _buildSecurity(p);
      default:
        return _buildDone(p);
    }
  }

  /// Scrollable step body shared by every step so the footer stays reachable
  /// when the keyboard opens and content never overflows at larger text scale.
  Widget _scroll({
    required List<Widget> children,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
    bool center = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
          child: Column(
            crossAxisAlignment: crossAxisAlignment,
            mainAxisAlignment: center
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildWelcome(AppPalette p) {
    return _scroll(
      crossAxisAlignment: CrossAxisAlignment.center,
      center: true,
      children: [
        FadeSlideIn(child: const OnbLogoArt()),
        const SizedBox(height: 6),
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
        const SizedBox(height: 22),
        FadeSlideIn(
          index: 3,
          child: TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            textAlign: TextAlign.center,
            textInputAction: TextInputAction.done,
            inputFormatters: [LengthLimitingTextInputFormatter(40)],
            decoration: const InputDecoration(
              labelText: 'Your name (optional)',
              hintText: 'What should we call you?',
            ),
          ),
        ),
        const SizedBox(height: 24),
        FadeSlideIn(
          index: 4,
          child: PrimaryButton(label: 'Get started', onPressed: _next),
        ),
        const SizedBox(height: 14),
        Text(
          'Private · Offline · No sign-up · No ads',
          textAlign: TextAlign.center,
          style: AppText.caption(p.muted),
        ),
      ],
    );
  }

  Widget _buildFeature(
    AppPalette p, {
    required Widget art,
    required String title,
    required String subtitle,
  }) {
    return _scroll(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FadeSlideIn(child: art),
        const SizedBox(height: 8),
        FadeSlideIn(
          index: 1,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.display(p.ink).copyWith(fontSize: 28),
          ),
        ),
        const SizedBox(height: 10),
        FadeSlideIn(
          index: 2,
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppText.caption(p.muted).copyWith(fontSize: 14, height: 1.6),
          ),
        ),
        const SizedBox(height: 28),
        FadeSlideIn(
          index: 3,
          child: PrimaryButton(label: 'Next', onPressed: _next),
        ),
      ],
    );
  }

  Widget _buildAccount(AppPalette p) {
    return _scroll(
      children: [
        FadeSlideIn(
          child: Text(
            'Add your first bank account',
            style: AppText.display(p.ink),
          ),
        ),
        const SizedBox(height: 8),
        FadeSlideIn(
          index: 1,
          child: Text(
            'Use the balance you have right now. You can change it any time.',
            style: AppText.caption(p.muted).copyWith(fontSize: 14, height: 1.6),
          ),
        ),
        const SizedBox(height: 20),
        FadeSlideIn(
          index: 2,
          child: TextField(
            controller: _accountNameController,
            focusNode: _accountNameFocusNode,
            textInputAction: TextInputAction.next,
            inputFormatters: [LengthLimitingTextInputFormatter(40)],
            onChanged: (v) {
              // Live: re-enable Continue and update the message per keystroke.
              setState(() {
                _accountError =
                    (v.trim().isEmpty && _queuedAccounts.isEmpty)
                    ? 'Enter an account name.'
                    : null;
              });
            },
            decoration: InputDecoration(
              labelText: 'Account name',
              hintText: 'e.g. SBI',
              errorText: _accountError,
            ),
          ),
        ),
        const SizedBox(height: 12),
        FadeSlideIn(
          index: 2,
          child: TextField(
            controller: _balanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: AmountInput.amountFormatters(),
            onChanged: (v) =>
                setState(() => _balanceError = _validateBalance(v)),
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            decoration: InputDecoration(
              labelText: 'Current balance',
              prefixText: '₹ ',
              hintText: '0',
              errorText: _balanceError,
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_queuedAccounts.isNotEmpty) ...[
          for (var i = 0; i < _queuedAccounts.length; i++)
            FadeSlideIn(
              key: ValueKey<String>(_queuedAccounts[i].id),
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SettingsGroup(
                  children: [
                    ListRowTile(
                      emoji: '🏦',
                      title: _queuedAccounts[i].name,
                      trailing: Text(
                        CurrencyFormatter.format(
                          _queuedAccounts[i].currentBalance,
                        ),
                        style: AppText.amount(p.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 2),
        ],
        FadeSlideIn(
          index: 3,
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addAnotherAccount,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Add another bank account'),
              style: TextButton.styleFrom(foregroundColor: p.primary),
            ),
          ),
        ),
        const SizedBox(height: 4),
        FadeSlideIn(
          index: 4,
          child: Text(
            'Cash is a payment method in MyKhata, so you don’t need a Cash account.',
            style: AppText.caption(p.muted),
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Continue',
          onPressed: _accountExists ? _continueFromAccount : null,
        ),
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
    ) => ListRowTile(
      emoji: emoji,
      title: title,
      subtitle: subtitle,
      trailing: Switch(
        value: value,
        activeThumbColor: p.primary,
        onChanged: onChanged,
      ),
    );

    return _scroll(
      children: [
        FadeSlideIn(
          child: Text('A few permissions', style: AppText.display(p.ink)),
        ),
        const SizedBox(height: 8),
        FadeSlideIn(
          index: 1,
          child: Text(
            'Each one is optional. We only use them for the reason shown.',
            style: AppText.caption(p.muted).copyWith(fontSize: 14, height: 1.6),
          ),
        ),
        const SizedBox(height: 16),
        FadeSlideIn(
          index: 2,
          child: SettingsGroup(
            children: [
              row(
                '🔔',
                'Notifications',
                'Budget alerts and payment reminders',
                _notifEnabled,
                (v) => setState(() => _notifEnabled = v),
              ),
              row(
                '📍',
                'Location',
                'Saved with an expense, only at the moment you save',
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
                '🖼️',
                'Photos',
                'Attach receipts from your gallery',
                _photosEnabled,
                (v) => setState(() => _photosEnabled = v),
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
        ),
        const SizedBox(height: 12),
        FadeSlideIn(
          index: 3,
          child: Text(
            'You can change these later in Settings.',
            style: AppText.caption(p.muted),
          ),
        ),
        const SizedBox(height: 24),
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
    return _scroll(
      crossAxisAlignment: CrossAxisAlignment.center,
      center: true,
      children: [
        FadeSlideIn(
          child: OnbFingerprint(
            onTap: _enableBiometrics,
            ok: _biometricSuccess,
          ),
        ),
        const SizedBox(height: 34),
        FadeSlideIn(
          index: 1,
          child: Text(
            'Lock it down',
            textAlign: TextAlign.center,
            style: AppText.display(p.ink),
          ),
        ),
        const SizedBox(height: 10),
        FadeSlideIn(
          index: 2,
          child: Text(
            "Open MyKhata with your fingerprint or face. If that doesn't work, your phone's PIN or pattern does.",
            textAlign: TextAlign.center,
            style: AppText.caption(p.muted).copyWith(fontSize: 14, height: 1.6),
          ),
        ),
        const SizedBox(height: 36),
        FadeSlideIn(
          index: 3,
          child: PrimaryButton(
            label: _biometricSuccess
                ? 'Biometric lock on'
                : 'Enable biometric lock',
            icon: Icons.lock_rounded,
            onPressed: _biometricSuccess ? null : _enableBiometrics,
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: _biometricSuccess ? null : _next,
          style: TextButton.styleFrom(foregroundColor: p.muted),
          child: const Text('Maybe later'),
        ),
      ],
    );
  }

  Widget _buildDone(AppPalette p) {
    final name = _nameController.text.trim();
    final names = _plannedAccountNames();
    final accountsLine = names.isEmpty
        ? 'Ready to track.'
        : '${names.join(' and ')} ready to track.';

    return _scroll(
      crossAxisAlignment: CrossAxisAlignment.center,
      center: true,
      children: [
        const OnbDoneArt(),
        const SizedBox(height: 8),
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
            '$accountsLine Tap + on Home whenever you spend.',
            textAlign: TextAlign.center,
            style: AppText.caption(p.muted).copyWith(fontSize: 14, height: 1.6),
          ),
        ),
        const SizedBox(height: 40),
        FadeSlideIn(
          index: 3,
          child: PrimaryButton(
            label: 'Open MyKhata',
            loading: _finishing,
            onPressed: _completeOnboarding,
          ),
        ),
      ],
    );
  }
}
