import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/account_model.dart';
import '../../providers/account_providers.dart';
import '../../providers/auth_provider.dart';
import '../main/main_navigation_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentStep = 0; // 0 to 7 (8 steps matching MyKhata onboarding.html)

  final TextEditingController _accountNameController = TextEditingController(text: 'SBI');
  final TextEditingController _balanceController = TextEditingController(text: '50000');
  final FocusNode _accountNameFocusNode = FocusNode();
  final Uuid _uuid = const Uuid();

  final List<AccountModel> _queuedAccounts = [];

  bool _notifEnabled = true;
  bool _locEnabled = true;
  bool _camEnabled = true;
  bool _photosEnabled = true;
  bool _smsEnabled = true;

  bool _biometricSuccess = false;

  @override
  void dispose() {
    _accountNameController.dispose();
    _balanceController.dispose();
    _accountNameFocusNode.dispose();
    super.dispose();
  }

  void _addAnotherAccount() {
    final name = _accountNameController.text.trim();
    final balance = double.tryParse(_balanceController.text.trim()) ?? 0.0;
    if (name.isEmpty) return;

    setState(() {
      _queuedAccounts.add(
        AccountModel(
          id: _uuid.v4(),
          name: name,
          currentBalance: balance,
          initialBalance: balance,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      _accountNameController.clear();
      _balanceController.clear();
    });
    _accountNameFocusNode.requestFocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Another account added to queue')),
    );
  }

  Future<void> _completeOnboarding() async {
    final navigator = Navigator.of(context);

    try {
      final name = _accountNameController.text.trim();
      final balance = double.tryParse(_balanceController.text.trim()) ?? 0.0;
      if (name.isNotEmpty && _queuedAccounts.isEmpty) {
        _queuedAccounts.add(
          AccountModel(
            id: _uuid.v4(),
            name: name,
            currentBalance: balance,
            initialBalance: balance,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      if (_queuedAccounts.isEmpty) {
        _queuedAccounts.add(
          AccountModel(
            id: _uuid.v4(),
            name: 'SBI',
            currentBalance: 50000.0,
            initialBalance: 50000.0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      for (final acc in _queuedAccounts) {
        await ref.read(accountListProvider.notifier).createAccount(acc);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save accounts: $e')),
        );
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefIsOnboardingComplete, true);
    await prefs.setBool(AppConstants.prefAutoSmsDetection, _smsEnabled);
    await prefs.setBool(AppConstants.prefAutoLocationCapture, _locEnabled);

    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? AppColors.darkInk : AppColors.ink;
    final mutedColor = isDark ? AppColors.darkMuted : AppColors.muted;
    final linesColor = isDark ? AppColors.darkLines : AppColors.lines;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final surface2Color = isDark ? AppColors.darkSurface2 : AppColors.surface2;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Back, Progress Bars, Skip
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                children: [
                  if (_currentStep > 0 && _currentStep < 7)
                    TextButton(
                      onPressed: () => setState(() => _currentStep--),
                      style: TextButton.styleFrom(foregroundColor: mutedColor),
                      child: const Text('‹ Back'),
                    )
                  else
                    const SizedBox(width: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: List.generate(8, (i) {
                        final isOn = i <= _currentStep;
                        return Expanded(
                          child: Container(
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: isOn ? AppColors.primary : linesColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (_currentStep > 0 && _currentStep < 4)
                    TextButton(
                      onPressed: () => setState(() => _currentStep = 4),
                      style: TextButton.styleFrom(foregroundColor: mutedColor),
                      child: const Text('Skip'),
                    )
                  else
                    const SizedBox(width: 40),
                ],
              ),
            ),

            // Step Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                child: _buildCurrentStep(inkColor, mutedColor, linesColor, surfaceColor, surface2Color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep(
    Color inkColor,
    Color mutedColor,
    Color linesColor,
    Color surfaceColor,
    Color surface2Color,
  ) {
    switch (_currentStep) {
      case 0:
        return _buildStepWelcome(inkColor, mutedColor, surface2Color);
      case 1:
        return _buildStepFeature(
          emoji: '💬',
          title: 'Bank messages, sorted for you',
          subtitle: 'MyKhata spots transaction SMS and lines them up for review. Nothing is added until you confirm it.',
        );
      case 2:
        return _buildStepFeature(
          emoji: '🧾',
          title: 'Keep receipts with the expense',
          subtitle: 'Snap or attach receipts. They stay on this phone, next to the expense they belong to.',
        );
      case 3:
        return _buildStepFeature(
          emoji: '📊',
          title: 'Budgets that tell you early',
          subtitle: 'Set a limit, then get a nudge at 75%, 90% and 100%. Once per period, never spam.',
        );
      case 4:
        return _buildStepAddAccount(inkColor, mutedColor, linesColor, surfaceColor, surface2Color);
      case 5:
        return _buildStepPermissions(inkColor, mutedColor, linesColor, surfaceColor, surface2Color);
      case 6:
        return _buildStepBiometric(inkColor, mutedColor, surface2Color);
      case 7:
      default:
        return _buildStepComplete(inkColor, mutedColor, surface2Color);
    }
  }

  Widget _buildStepWelcome(Color inkColor, Color mutedColor, Color surface2Color) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            gradient: AppColors.heroGradientLight,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(color: Color(0x665B3DF5), blurRadius: 24, offset: Offset(0, 10)),
            ],
          ),
          child: const Center(
            child: Text('₹', style: TextStyle(fontSize: 42, color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'MyKhata',
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: inkColor, letterSpacing: -0.8),
        ),
        const SizedBox(height: 12),
        Text(
          'Record, understand and monitor your money with the least possible effort.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: mutedColor, height: 1.6),
        ),
        const SizedBox(height: 60),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () => setState(() => _currentStep++),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Get started', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Private · Offline · No sign-up · No ads',
          style: TextStyle(fontSize: 12, color: mutedColor),
        ),
      ],
    );
  }

  Widget _buildStepFeature({required String emoji, required String title, required String subtitle}) {
    return Column(
      children: [
        const SizedBox(height: 60),
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 54)),
          ),
        ),
        const SizedBox(height: 40),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8),
        ),
        const SizedBox(height: 16),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.6),
        ),
        const SizedBox(height: 80),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () => setState(() => _currentStep++),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Next', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildStepAddAccount(
    Color inkColor,
    Color mutedColor,
    Color linesColor,
    Color surfaceColor,
    Color surface2Color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add your first bank account',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: inkColor, letterSpacing: -0.8),
        ),
        const SizedBox(height: 8),
        Text(
          'Use the balance you have right now. You can change it any time.',
          style: TextStyle(fontSize: 14, color: mutedColor, height: 1.5),
        ),
        const SizedBox(height: 28),

        // Account Name
        Text('Account name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: mutedColor)),
        const SizedBox(height: 6),
        TextField(
          controller: _accountNameController,
          focusNode: _accountNameFocusNode,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: inkColor),
          decoration: InputDecoration(
            fillColor: surfaceColor,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: linesColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
          ),
        ),
        const SizedBox(height: 18),

        // Current Balance
        Text('Current balance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: mutedColor)),
        const SizedBox(height: 6),
        TextField(
          controller: _balanceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: inkColor),
          decoration: InputDecoration(
            prefixText: '₹ ',
            prefixStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: inkColor),
            fillColor: surfaceColor,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: linesColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
          ),
        ),

        const SizedBox(height: 16),

        // Queued accounts list
        if (_queuedAccounts.isNotEmpty) ...[
          ..._queuedAccounts.map((acc) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: linesColor),
            ),
            child: Row(
              children: [
                const Text('🏦', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(child: Text(acc.name, style: TextStyle(fontWeight: FontWeight.w700, color: inkColor))),
                Text(CurrencyFormatter.format(acc.currentBalance), style: TextStyle(fontWeight: FontWeight.w700, color: inkColor)),
              ],
            ),
          )),
          const SizedBox(height: 8),
        ],

        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: _addAnotherAccount,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            child: const Text('+ Add another bank account'),
          ),
        ),

        const SizedBox(height: 8),
        Text(
          'Cash is a payment method in MyKhata, so you don’t need a Cash account.',
          style: TextStyle(fontSize: 12, color: mutedColor, height: 1.4),
        ),
        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () => setState(() => _currentStep++),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildStepPermissions(
    Color inkColor,
    Color mutedColor,
    Color linesColor,
    Color surfaceColor,
    Color surface2Color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'A few permissions',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: inkColor, letterSpacing: -0.8),
        ),
        const SizedBox(height: 8),
        Text(
          'Each one is optional. We only use them for the reason shown.',
          style: TextStyle(fontSize: 14, color: mutedColor, height: 1.5),
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: linesColor),
          ),
          child: Column(
            children: [
              _buildPermRow(emoji: '🔔', title: 'Notifications', subtitle: 'Budget alerts and payment reminders', value: _notifEnabled, onChanged: (v) => setState(() => _notifEnabled = v), linesColor: linesColor, inkColor: inkColor, mutedColor: mutedColor, surface2Color: surface2Color),
              _buildPermRow(emoji: '📍', title: 'Location', subtitle: 'Saved with an expense, only at the moment you save', value: _locEnabled, onChanged: (v) async {
                if (v) await PermissionService.requestLocationPermission();
                setState(() => _locEnabled = v);
              }, linesColor: linesColor, inkColor: inkColor, mutedColor: mutedColor, surface2Color: surface2Color),
              _buildPermRow(emoji: '📷', title: 'Camera', subtitle: 'Photograph receipts', value: _camEnabled, onChanged: (v) async {
                if (v) await PermissionService.requestCameraPermission();
                setState(() => _camEnabled = v);
              }, linesColor: linesColor, inkColor: inkColor, mutedColor: mutedColor, surface2Color: surface2Color),
              _buildPermRow(emoji: '🖼️', title: 'Photos', subtitle: 'Attach receipts from your gallery', value: _photosEnabled, onChanged: (v) => setState(() => _photosEnabled = v), linesColor: linesColor, inkColor: inkColor, mutedColor: mutedColor, surface2Color: surface2Color),
              _buildPermRow(emoji: '💬', title: 'SMS', subtitle: 'Detect bank messages so you can review them', value: _smsEnabled, onChanged: (v) async {
                if (v) await PermissionService.requestSmsPermission();
                setState(() => _smsEnabled = v);
              }, linesColor: linesColor, inkColor: inkColor, mutedColor: mutedColor, surface2Color: surface2Color, isLast: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('You can change these later in Settings.', style: TextStyle(fontSize: 12, color: mutedColor)),
        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () => setState(() => _currentStep++),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Allow selected', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildStepBiometric(Color inkColor, Color mutedColor, Color surface2Color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Text(
          'Lock it down',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: inkColor, letterSpacing: -0.8),
        ),
        const SizedBox(height: 8),
        Text(
          "Open MyKhata with your fingerprint or face. If that doesn't work, your phone's PIN or pattern does.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: mutedColor, height: 1.6),
        ),
        const SizedBox(height: 50),

        Center(
          child: GestureDetector(
            onTap: () async {
              await ref.read(authProvider.notifier).toggleBiometrics(true);
              if (!mounted) return;
              setState(() => _biometricSuccess = true);
              await Future<void>.delayed(const Duration(milliseconds: 600));
              if (!mounted) return;
              setState(() => _currentStep++);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: _biometricSuccess ? AppColors.income : surface2Color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_biometricSuccess ? AppColors.income : AppColors.primary).withValues(alpha: 0.3),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _biometricSuccess ? '✓' : '👆',
                  style: TextStyle(fontSize: 50, color: _biometricSuccess ? Colors.white : null),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Tap to turn on biometric lock', style: TextStyle(fontSize: 13, color: mutedColor, fontWeight: FontWeight.w600)),
        const SizedBox(height: 60),

        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () async {
              await ref.read(authProvider.notifier).toggleBiometrics(true);
              if (!mounted) return;
              setState(() => _currentStep++);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Enable biometric lock', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => setState(() => _currentStep++),
          child: Text('Maybe later', style: TextStyle(color: mutedColor, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildStepComplete(Color inkColor, Color mutedColor, Color surface2Color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Container(
          width: 110,
          height: 110,
          decoration: const BoxDecoration(
            color: AppColors.income,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('✓', style: TextStyle(fontSize: 60, color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          "You're all set",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: inkColor, letterSpacing: -0.8),
        ),
        const SizedBox(height: 12),
        Text(
          'Ready to track. Tap + on Home whenever you spend.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: mutedColor, height: 1.6),
        ),
        const SizedBox(height: 80),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _completeOnboarding,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Open MyKhata', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildPermRow({
    required String emoji,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color linesColor,
    required Color inkColor,
    required Color mutedColor,
    required Color surface2Color,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: linesColor)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: surface2Color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 19)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: inkColor),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: mutedColor),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
