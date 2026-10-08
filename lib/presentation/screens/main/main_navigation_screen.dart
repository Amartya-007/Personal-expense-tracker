import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/pressable.dart';
import '../add_transaction/add_transaction_screen.dart';
import '../budgets/budget_list_screen.dart';
import '../home/home_screen.dart';
import '../insights/insights_screen.dart';
import '../settings/settings_screen.dart';
import '../transactions/transaction_history_screen.dart';

/// Tabs on which the "add transaction" speed-dial is shown.
const Set<int> _fabTabs = {0, 1};

const double _navHeight = 66;
const double _fabSize = 58;

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fabController;
  late final Animation<double> _fabRotation;
  late final Animation<double> _overlayOpacity;

  bool _isFabOpen = false;

  static const MethodChannel _intentChannel = MethodChannel(
    'com.MyKhata.mykhata/intent',
  );

  static const List<Widget> _screens = [
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
      CurvedAnimation(parent: _fabController, curve: AppMotion.enter),
    );
    _overlayOpacity = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeInOut,
    );

    _initIntentListener();
  }

  Future<void> _initIntentListener() async {
    _intentChannel.setMethodCallHandler((call) async {
      if (call.method == 'handleIntentAction') {
        _handleAction(call.arguments?.toString());
      }
    });

    try {
      final initialAction = await _intentChannel.invokeMethod<String>(
        'getInitialIntentAction',
      );
      if (initialAction != null) _handleAction(initialAction);
    } catch (_) {}
  }

  void _handleAction(String? action) {
    if (!mounted) return;
    if (action == 'com.MyKhata.mykhata.ACTION_ADD_EXPENSE') {
      AppRoutes.pushModal(
        context,
        const AddTransactionScreen(initialType: 'expense'),
      );
    } else if (action == 'com.MyKhata.mykhata.ACTION_VIEW_BUDGETS') {
      ref.read(mainTabProvider.notifier).state = 2;
    }
  }

  @override
  void dispose() {
    _intentChannel.setMethodCallHandler(null);
    _fabController.dispose();
    super.dispose();
  }

  void _toggleFab() {
    HapticFeedback.lightImpact();
    setState(() => _isFabOpen = !_isFabOpen);
    _isFabOpen ? _fabController.forward() : _fabController.reverse();
  }

  void _closeFab() {
    if (!_isFabOpen) return;
    setState(() => _isFabOpen = false);
    _fabController.reverse();
  }

  void _openAddTransaction(String type) {
    _closeFab();
    AppRoutes.pushModal(context, AddTransactionScreen(initialType: type));
  }

  void _selectTab(int index) {
    if (ref.read(mainTabProvider) != index) HapticFeedback.selectionClick();
    _closeFab();
    ref.read(mainTabProvider.notifier).state = index;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(mainTabProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final navBottom = math.max(12.0, bottomPadding);
    final fabBottom = navBottom + _navHeight + 16;
    final dialBottom = fabBottom + _fabSize + 14;
    final showFab = _fabTabs.contains(currentIndex);

    // The speed-dial belongs to the Home/Transactions tabs, close it if the
    // tab changes some other way (e.g. a shortcut intent).
    ref.listen<int>(mainTabProvider, (previous, next) {
      if (!_fabTabs.contains(next)) _closeFab();
    });

    final shell = PopScope(
      // Back: close the speed-dial first, then go to Home, then leave the app.
      canPop: currentIndex == 0 && !_isFabOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isFabOpen) {
          _closeFab();
        } else {
          ref.read(mainTabProvider.notifier).state = 0;
        }
      },
      child: Scaffold(
        backgroundColor: context.palette.background,
        body: Stack(
          children: [
            _AnimatedTabBody(index: currentIndex, children: _screens),

            // Scrim. Stays mounted while the fade-out plays (it used to be
            // removed instantly when closing).
            AnimatedBuilder(
              animation: _fabController,
              builder: (context, _) {
                if (_fabController.isDismissed) return const SizedBox.shrink();
                return Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !_isFabOpen,
                    child: GestureDetector(
                      onTap: _closeFab,
                      behavior: HitTestBehavior.opaque,
                      child: FadeTransition(
                        opacity: _overlayOpacity,
                        child: Container(color: const Color(0x800F0E28)),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Speed-dial options.
            AnimatedBuilder(
              animation: _fabController,
              builder: (context, _) {
                if (_fabController.isDismissed) return const SizedBox.shrink();
                return Positioned(
                  right: 20,
                  bottom: dialBottom,
                  child: IgnorePointer(
                    ignoring: !_isFabOpen,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildSpeedDialOption(
                          title: 'Transfer',
                          type: 'transfer',
                          icon: Icons.swap_horiz_rounded,
                          index: 2,
                        ),
                        const SizedBox(height: 12),
                        _buildSpeedDialOption(
                          title: 'Income',
                          type: 'income',
                          icon: Icons.south_west_rounded,
                          index: 1,
                        ),
                        const SizedBox(height: 12),
                        _buildSpeedDialOption(
                          title: 'Expense',
                          type: 'expense',
                          icon: Icons.north_east_rounded,
                          index: 0,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // FAB: animates in/out as tabs change instead of popping.
            Positioned(
              right: 20,
              bottom: fabBottom,
              child: IgnorePointer(
                ignoring: !showFab,
                child: AnimatedScale(
                  scale: showFab ? 1 : 0,
                  duration: AppMotion.medium,
                  curve: showFab ? AppMotion.bounce : AppMotion.exit,
                  child: AnimatedOpacity(
                    opacity: showFab ? 1 : 0,
                    duration: AppMotion.fast,
                    child: _buildFab(context),
                  ),
                ),
              ),
            ),

            // Floating pill navigation bar.
            Positioned(
              left: 14,
              right: 14,
              bottom: navBottom,
              child: _FloatingNavBar(
                currentIndex: currentIndex,
                onSelect: _selectTab,
              ),
            ),
          ],
        ),
      ),
    );

    // The nav pill and add button float inside the body, so a snackbar would
    // otherwise be drawn right on top of them. Lift snackbars shown on this
    // screen above the nav pill (and above the add button while it is
    // visible). Screens pushed over this one have no nav pill and keep the
    // default position.
    final theme = Theme.of(context);
    final snackBottom = showFab
        ? fabBottom + _fabSize + 10
        : navBottom + _navHeight + 10;
    return Theme(
      data: theme.copyWith(
        snackBarTheme: theme.snackBarTheme.copyWith(
          insetPadding: EdgeInsets.fromLTRB(14, 0, 14, snackBottom),
        ),
      ),
      child: shell,
    );
  }

  Widget _buildFab(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: _isFabOpen ? 'Close add menu' : 'Add transaction',
      child: Pressable(
        onTap: _toggleFab,
        child: Container(
          width: _fabSize,
          height: _fabSize,
          decoration: BoxDecoration(
            color: p.secondary,
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
              builder: (context, child) =>
                  Transform.rotate(angle: _fabRotation.value, child: child),
              child: const Icon(
                Icons.add,
                size: 32,
                color: Color(0xFF2A1D00),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedDialOption({
    required String title,
    required String type,
    required IconData icon,
    required int index,
  }) {
    final p = context.palette;
    final color = switch (type) {
      'income' => p.income,
      'transfer' => p.primary,
      _ => p.expense,
    };

    return ScaleTransition(
      alignment: Alignment.centerRight,
      scale: CurvedAnimation(
        parent: _fabController,
        curve: Interval(0.1 * index, 1.0, curve: AppMotion.bounce),
      ),
      child: FadeTransition(
        opacity: _overlayOpacity,
        child: Pressable(
          onTap: () => _openAddTransaction(type),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 18, 10),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [p.cardShadow],
              border: Border.all(color: p.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Text(title, style: AppText.bodyStrong(p.ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps every visited tab alive (scroll position, filters, form state) but
/// cross-fades and gently lifts the tab you switch to. The old `IndexedStack`
/// swapped tabs instantly, and built all five tabs at launch.
class _AnimatedTabBody extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const _AnimatedTabBody({required this.index, required this.children});

  @override
  State<_AnimatedTabBody> createState() => _AnimatedTabBodyState();
}

class _AnimatedTabBodyState extends State<_AnimatedTabBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _lift;
  final Set<int> _visited = {};

  @override
  void initState() {
    super.initState();
    _visited.add(widget.index);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: 1.0,
    );
    final curve = CurvedAnimation(parent: _controller, curve: AppMotion.enter);
    _fade = curve;
    _lift = Tween<Offset>(
      begin: const Offset(0, 0.02),
      end: Offset.zero,
    ).animate(curve);
  }

  @override
  void didUpdateWidget(covariant _AnimatedTabBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _visited.add(widget.index);
      if (MediaQuery.of(context).disableAnimations) {
        _controller.value = 1.0;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          // The wrapper structure is identical for every tab so switching
          // never rebuilds a tab's subtree and loses its state.
          Offstage(
            key: ValueKey('tab-$i'),
            offstage: i != widget.index,
            child: TickerMode(
              enabled: i == widget.index,
              child: FadeTransition(
                opacity: i == widget.index
                    ? _fade
                    : const AlwaysStoppedAnimation<double>(1.0),
                child: SlideTransition(
                  position: i == widget.index
                      ? _lift
                      : const AlwaysStoppedAnimation<Offset>(Offset.zero),
                  child: _visited.contains(i)
                      ? widget.children[i]
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NavItem {
  final String title;
  final IconData filled;
  final IconData outlined;

  const _NavItem(this.title, this.filled, this.outlined);
}

const List<_NavItem> _navItems = [
  _NavItem('Home', Icons.home_rounded, Icons.home_outlined),
  _NavItem(
    'Transactions',
    Icons.receipt_long_rounded,
    Icons.receipt_long_outlined,
  ),
  _NavItem('Budgets', Icons.pie_chart_rounded, Icons.pie_chart_outline_rounded),
  _NavItem('Insights', Icons.bar_chart_rounded, Icons.bar_chart_outlined),
  _NavItem('Settings', Icons.settings_rounded, Icons.settings_outlined),
];

class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;

  const _FloatingNavBar({required this.currentIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      height: _navHeight,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [p.cardShadow],
        border: Border.all(color: p.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / _navItems.length;

          return Stack(
            children: [
              // Sliding pill indicator.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.fastOutSlowIn,
                left: currentIndex * itemWidth,
                top: 0,
                bottom: 0,
                width: itemWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: p.surface2,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < _navItems.length; i++)
                    Expanded(
                      child: _NavButton(
                        item: _navItems[i],
                        selected: i == currentIndex,
                        onTap: () => onSelect(i),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = selected ? p.primary : p.muted;

    return Semantics(
      button: true,
      selected: selected,
      label: item.title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.12 : 1.0,
              duration: AppMotion.medium,
              curve: AppMotion.bounce,
              child: Icon(
                selected ? item.filled : item.outlined,
                size: 22,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: AppMotion.fast,
              style: AppText.caption(color).copyWith(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
