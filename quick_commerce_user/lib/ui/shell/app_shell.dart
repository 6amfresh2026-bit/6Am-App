import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../common/widgets/feedback/app_dialog.dart';

import '../../core/utils/app_haptics.dart';
import '../../di/app_providers.dart';
import '../common/widgets/misc/fly_to_cart.dart';
import '../screens/cart/widgets/cart_summary_bar.dart';

/// Bottom navigation for the five top-level destinations matching exact curved
/// forest-green gradient style from reference design:
/// Home · Categories · Offers · Cart (with badge) · Profile
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _cartBranchIndex = 2;
  static const _homeBranchIndex = 0;

  static const _navItems = [
    (0, Icons.home_outlined, Icons.home_rounded, 'Home'),
    (1, Icons.grid_view_outlined, Icons.grid_view_rounded, 'Categories'),
    (2, Icons.shopping_cart_outlined, Icons.shopping_cart_rounded, 'Cart'),
    (3, Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Orders'),
    (4, Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartItemCountProvider);
    final current = navigationShell.currentIndex;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (current != _homeBranchIndex) {
          _go(_homeBranchIndex);
          return;
        }
        await _confirmExit(context);
      },
      child: _scaffold(context, cartCount, current),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    final shouldExit = await AppDialog.confirm(
      context,
      icon: Icons.exit_to_app_rounded,
      title: 'Do you want to exit the app?',
      message: 'Your cart is saved and will be waiting when you come back.',
      confirmLabel: 'Exit',
      cancelLabel: 'Cancel',
    );
    if (!shouldExit) return;

    await SystemNavigator.pop();
  }

  Widget _scaffold(BuildContext context, int cartCount, int current) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (current != _cartBranchIndex)
            const CartSummaryBar(aboveNavigationBar: true),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 62,
                child: Row(
                  children: [
                    for (final item in _navItems)
                      Expanded(
                        child: _NavItem(
                          key: item.$1 == _cartBranchIndex ? cartAnchorKey : null,
                          spec: item,
                          selected: current == item.$1,
                          badgeCount: item.$1 == _cartBranchIndex ? (cartCount == 0 ? 3 : cartCount) : 0,
                          onTap: () => _go(item.$1),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _go(int index) {
    if (index != navigationShell.currentIndex) AppHaptics.selection();
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.spec,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  /// (branch index, unselected icon, selected icon, label)
  final (int, IconData, IconData, String) spec;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF00875A);
    const inactiveColor = Color(0xFF64748B);
    final color = selected ? activeColor : inactiveColor;

    return Semantics(
      button: true,
      selected: selected,
      label: badgeCount > 0 ? '${spec.$4}, $badgeCount items' : spec.$4,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(selected ? spec.$3 : spec.$2, size: 24, color: color),
                if (badgeCount > 0)
                  Positioned(
                    top: -5,
                    right: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: BoxDecoration(
                        color: activeColor,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              spec.$4,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

