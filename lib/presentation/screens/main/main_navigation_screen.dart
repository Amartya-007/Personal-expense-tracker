import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_providers.dart';
import '../add_transaction/add_transaction_screen.dart';
import '../budgets/budget_list_screen.dart';
import '../home/home_screen.dart';
import '../insights/insights_screen.dart';
import '../lock/lock_screen.dart';
import '../settings/settings_screen.dart';
import '../transactions/transaction_history_screen.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fabController;
  late Animation<double> _fabRotation;
  late Animation<double> _overlayOpacity;
  bool _isFabOpen = false;

  static const MethodChannel _intentChannel = MethodChannel('com.MyKhata.mykhata/intent');

  final List<Widget> _screens = const [
    HomeScreen(),
    TransactionHistoryScreen(),
    BudgetListScreen(),
    InsightsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fabRotation = Tween<double>(begin: 0.0, end: 135 * (math.pi / 180)).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.easeOutCubic),
    );
    _overlayOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.easeInOut),
    );

    _initIntentListener();
  }

  Future<void> _initIntentListener() async {
    _intentChannel.setMethodCallHandler((call) async {
      if (call.method == 'handleIntentAction') {
        final action = call.arguments?.toString();
        _handleAction(action);
      }
    });

    try {
      final initialAction = await _intentChannel.invokeMethod<String>('getInitialIntentAction');
      if (initialAction != null) {
        _handleAction(initialAction);
      }
    } catch (_) {}
  }

  void _handleAction(String? action) {
    if (!mounted) return;
    if (action == 'com.MyKhata.mykhata.ACTION_ADD_EXPENSE') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddTransactionScreen(initialType: 'expense')),
      );
    } else if (action == 'com.MyKhata.mykhata.ACTION_VIEW_BUDGETS') {
      ref.read(mainTabProvider.notifier).state = 2;
    }
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void _toggleFab() {
    setState(() {
      _isFabOpen = !_isFabOpen;
      if (_isFabOpen) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }
    });
  }

  void _closeFab() {
    if (_isFabOpen) {
      setState(() {
        _isFabOpen = false;
        _fabController.reverse();
      });
    }
  }

  void _openAddTransaction(String type) {
    _closeFab();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(initialType: type.toLowerCase()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    if (!authState.isUnlocked) {
      return const LockScreen();
    }

    final currentIndex = ref.watch(mainTabProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Stack(
        children: [
          // Screens Stack
          IndexedStack(
            index: currentIndex,
            children: _screens,
          ),

          // Speed Dial Scrim Overlay
          if (_isFabOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeFab,
                behavior: HitTestBehavior.opaque,
                child: FadeTransition(
                  opacity: _overlayOpacity,
                  child: Container(
                    color: AppColors.overlay,
                  ),
                ),
              ),
            ),

          // Speed Dial Action Options (Positioned higher up to avoid clipping under FAB)
          if (_isFabOpen || _fabController.isAnimating)
            Positioned(
              right: 20,
              bottom: 168 + bottomPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildSpeedDialOption(
                    title: 'Transfer',
                    type: 'transfer',
                    index: 2,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildSpeedDialOption(
                    title: 'Income',
                    type: 'income',
                    index: 1,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildSpeedDialOption(
                    title: 'Expense',
                    type: 'expense',
                    index: 0,
                    isDark: isDark,
                  ),
                ],
              ),
            ),

          // Speed Dial FAB Button (Only on Home screen, index 0)
          if (currentIndex == 0)
            Positioned(
              right: 20,
              bottom: 96 + bottomPadding,
              child: GestureDetector(
                onTap: _toggleFab,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.secondaryDark : AppColors.secondary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66FFB627),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _fabRotation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _fabRotation.value,
                          child: const Icon(
                            Icons.add,
                            size: 32,
                            color: AppColors.darkFabText,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

          // Floating Pill Bottom Navigation Bar
          Positioned(
            left: 14,
            right: 14,
            bottom: math.max(12, bottomPadding),
            child: _buildFloatingNavBar(context, currentIndex, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedDialOption({
    required String title,
    required String type,
    required int index,
    required bool isDark,
  }) {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _fabController,
        curve: Interval(0.1 * index, 1.0, curve: Curves.easeOutBack),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openAddTransaction(type),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
              ],
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                width: 1.0,
              ),
            ),
            child: Text(
              title,
              style: GoogleFonts.sora(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingNavBar(BuildContext context, int currentIndex, bool isDark) {
    const navItems = [
      {'title': 'Home', 'icon': Icons.home_rounded, 'outlined': Icons.home_outlined},
      {'title': 'Transactions', 'icon': Icons.receipt_long_rounded, 'outlined': Icons.receipt_long_outlined},
      {'title': 'Budgets', 'icon': Icons.pie_chart_rounded, 'outlined': Icons.pie_chart_outline_rounded},
      {'title': 'Insights', 'icon': Icons.bar_chart_rounded, 'outlined': Icons.bar_chart_outlined},
      {'title': 'Settings', 'icon': Icons.settings_rounded, 'outlined': Icons.settings_outlined},
    ];

    return Container(
      height: 66,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
        ],
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.0,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / navItems.length;

          return Stack(
            children: [
              // Animated Sliding Pill Indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.fastOutSlowIn,
                left: currentIndex * itemWidth,
                top: 0,
                bottom: 0,
                width: itemWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surface2Dark : AppColors.surface2Light,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),

              // Navigation Buttons
              Row(
                children: List.generate(navItems.length, (index) {
                  final item = navItems[index];
                  final isSelected = currentIndex == index;
                  final activeColor = isDark ? AppColors.primaryDark : AppColors.primary;
                  final inactiveColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _closeFab();
                        ref.read(mainTabProvider.notifier).state = index;
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isSelected ? (item['icon'] as IconData) : (item['outlined'] as IconData),
                            size: 22,
                            color: isSelected ? activeColor : inactiveColor,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item['title'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.sora(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected ? activeColor : inactiveColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
