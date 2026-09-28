import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../domain/model/cart.dart';
import '../../../core/extensions/num_extensions.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../di/app_providers.dart';
import '../../../di/service_providers.dart';
import '../../../domain/model/product.dart';
import '../../../navigation/route_paths.dart';
import '../monthly_list/widgets/save_cart_as_list_button.dart';
import '../../common/widgets/buttons/primary_button.dart';
import '../../common/widgets/cards/product_card.dart';
import '../../common/widgets/feedback/app_dialog.dart';
import '../../common/widgets/misc/section_header.dart';
import '../../common/widgets/states/empty_state_widget.dart';
import '../../common/widgets/states/offline_banner.dart';
import '../home/home_provider.dart';
import 'widgets/bill_details_card.dart';
import 'widgets/cart_line_tile.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key, this.showAppBar = true});

  /// The cart tab supplies its own chrome; the pushed route wants an app bar.
  final bool showAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cartProvider);
    final cart = state.cart;
    final pricingService = ref.watch(cartPricingServiceProvider);

    if (cart.isEmpty) {
      return Scaffold(
        appBar: showAppBar ? AppBar(title: const Text('Your cart')) : null,
        body: SafeArea(
          child: EmptyStateWidget(
            icon: Icons.shopping_basket_outlined,
            title: 'Your cart is empty',
            message:
                'Add a few essentials and we will have them at your door in minutes.',
            actionLabel: 'Browse products',
            onAction: () => context.go(RoutePaths.home),
          ),
        ),
      );
    }

    final freeDeliveryGap = pricingService.amountToFreeDelivery(cart);
    final crossSell = _crossSell(ref, cart.items.map((i) => i.product.id).toSet());

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: const Text('Your cart'),
              actions: [
                TextButton(
                  onPressed: () => _confirmClear(context, ref),
                  child: Text(
                    'Clear',
                    style: context.text.labelMedium!
                        .copyWith(color: context.semantic.danger),
                  ),
                ),
              ],
            )
          : null,
      bottomNavigationBar: _CheckoutBar(
        total: cart.pricing.total > 0
            ? cart.pricing.total
            : cart.provisionalSubtotal,
        itemCount: cart.itemCount,
        isPricing: state.isPricing,
        onCheckout: () => context.push(RoutePaths.checkout),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          children: [
            const OfflineBanner(),
            if (cart.priceChanges.isNotEmpty)
              _PriceChangeNotice(changes: cart.priceChanges),
            if (freeDeliveryGap > 0)
              _FreeDeliveryNudge(amount: freeDeliveryGap)
            else if (cart.pricing.isFreeDelivery && cart.pricing.total > 0)
              const _FreeDeliveryEarned(),
            _SellerHeader(
              name: cart.sellerName,
              etaMinutes: cart.pricing.deliveryPromiseMinutes,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: [
                  for (final item in cart.items)
                    CartLineTile(
                      item: item,
                      onIncrement: () =>
                          ref.read(cartProvider.notifier).increment(item.lineId),
                      onDecrement: () =>
                          ref.read(cartProvider.notifier).decrement(item.lineId),
                      onRemove: () =>
                          ref.read(cartProvider.notifier).removeLine(item.lineId),
                      onTap: () => context.push(
                        RoutePaths.productDetailsOf(item.product.id),
                        extra: item.product,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _CouponRow(
              pricing: cart.pricing,
              onApply: () => context.push(RoutePaths.coupons),
              onRemove: () => ref.read(cartProvider.notifier).removeCoupon(),
            ),
            if (crossSell.isNotEmpty) ...[
              const SectionHeader(
                title: 'Add these to your order',
                subtitle: 'People often buy these together',
              ),
              SizedBox(
                height: 285,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  itemCount: crossSell.length,
                  separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
                  itemBuilder: (context, index) => ProductCard(
                    product: crossSell[index],
                    heroTag: 'cart-cross-sell',
                    onTap: () => context.push(
                      RoutePaths.productDetailsOf(crossSell[index].id),
                      extra: crossSell[index],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SaveCartAsListButton(cart: cart),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: BillDetailsCard(
                lines: pricingService.billLines(cart),
                savings: cart.totalSavings,
                isPricing: state.isPricing,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cross-sell drawn from home's already-fetched catalog — no extra request.
  List<Product> _crossSell(WidgetRef ref, Set<String> inCart) {
    final sections = ref.watch(homeProvider).sections;
    final seen = <String>{};
    final suggestions = <Product>[];

    for (final section in sections) {
      for (final product in section.products) {
        if (inCart.contains(product.id) || !seen.add(product.id)) continue;
        if (!product.isPurchasable) continue;
        suggestions.add(product);
        if (suggestions.length == 10) return suggestions;
      }
    }
    return suggestions;
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialog.confirm(
      context,
      icon: Icons.remove_shopping_cart_outlined,
      title: 'Clear your cart?',
      message: 'This removes everything you have added so far.',
      confirmLabel: 'Clear cart',
      destructive: true,
    );
    if (confirmed) await ref.read(cartProvider.notifier).clear();
  }
}

class _SellerHeader extends StatelessWidget {
  const _SellerHeader({required this.name, this.etaMinutes});

  final String name;
  final int? etaMinutes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.storefront_rounded, size: 17, color: context.colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              name.isEmpty ? 'Your order' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleMedium,
            ),
          ),
          if (etaMinutes != null)
            Text(
              'Arrives in ${etaMinutes!.asDurationLabel}',
              style: context.text.labelMedium!
                  .copyWith(color: context.semantic.success),
            ),
        ],
      ),
    );
  }
}

class _FreeDeliveryNudge extends StatelessWidget {
  const _FreeDeliveryNudge({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.semantic.warningSoft,
        borderRadius: AppRadii.rMd,
      ),
      child: Row(
        children: [
          Icon(
            Icons.delivery_dining_rounded,
            size: 18,
            color: context.semantic.warning,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Add ${amount.asCurrency} more for free delivery',
              style: context.text.labelMedium!
                  .copyWith(color: context.semantic.warning),
            ),
          ),
        ],
      ),
    );
  }
}

class _FreeDeliveryEarned extends StatelessWidget {
  const _FreeDeliveryEarned();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.semantic.successSoft,
        borderRadius: AppRadii.rMd,
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: context.semantic.success,
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            'Free delivery unlocked',
            style: context.text.labelMedium!
                .copyWith(color: context.semantic.success),
          ),
        ],
      ),
    );
  }
}

class _PriceChangeNotice extends StatelessWidget {
  const _PriceChangeNotice({required this.changes});

  final List changes;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.semantic.dangerSoft,
        borderRadius: AppRadii.rMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_rounded, size: 18, color: context.semantic.danger),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '${changes.length} ${changes.length == 1 ? 'price has' : 'prices have'} '
              'changed since you added them. The bill below is current.',
              style: context.text.labelMedium!
                  .copyWith(color: context.semantic.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _CouponRow extends StatelessWidget {
  const _CouponRow({
    required this.pricing,
    required this.onApply,
    required this.onRemove,
  });

  final CartPricing pricing;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    // `couponCode` is echoed back even when the coupon was refused, so only
    // `appliedCoupon` can say whether it was actually honoured. Reading the
    // code as success is what printed "X applied · You saved ₹0" over a bill
    // that had refused it.
    final applied = pricing.isCouponApplied;
    final rejected = pricing.hasCouponError;
    final attemptedCode = pricing.couponCode ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: applied
            ? context.semantic.successSoft
            : rejected
                ? context.semantic.dangerSoft
                : context.colors.surface,
        borderRadius: AppRadii.rLg,
        border: Border.all(
          color: applied
              ? context.semantic.success
              : rejected
                  ? context.semantic.danger
                  : context.semantic.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_offer_rounded,
            size: 18,
            color: applied
                ? context.semantic.success
                : rejected
                    ? context.semantic.danger
                    : context.colors.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: applied
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${pricing.appliedCouponCode} applied',
                        style: context.text.titleSmall!
                            .copyWith(color: context.semantic.success),
                      ),
                      Text(
                        'You saved ${pricing.discount.asCurrency}',
                        style: context.text.bodySmall,
                      ),
                      // Nobody climbs a rung they were not told about.
                      if (pricing.nextSlab != null)
                        Text(
                          'Add ${pricing.nextSlab!.spendMore.asCurrency} more '
                          'to save ${pricing.nextSlab!.discount.asCurrency}',
                          style: context.text.bodySmall!
                              .copyWith(color: context.colors.primary),
                        ),
                    ],
                  )
                : rejected
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            attemptedCode.isEmpty
                                ? 'Coupon not applied'
                                : '$attemptedCode not applied',
                            style: context.text.titleSmall!
                                .copyWith(color: context.semantic.danger),
                          ),
                          // Verbatim: the server writes these for a customer
                          // to act on — "Needs ₹300 minimum — ₹2 more".
                          Text(
                            pricing.couponRejectedReason,
                            style: context.text.bodySmall,
                          ),
                        ],
                      )
                    : Text('Apply a coupon', style: context.text.titleMedium),
          ),
          if (applied)
            TextButton(
              onPressed: onRemove,
              child: Text(
                AppStrings.remove,
                style: context.text.labelMedium!
                    .copyWith(color: context.semantic.danger),
              ),
            )
          else
            TextButton(
              onPressed: onApply,
              child: Text(
                'View offers',
                style: context.text.labelMedium!
                    .copyWith(color: context.colors.primary),
              ),
            ),
        ],
      ),
    );
  }
}

/// Sticky checkout bar. Pulses once when a new item lands in the cart.
class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({
    required this.total,
    required this.itemCount,
    required this.isPricing,
    required this.onCheckout,
  });

  final double total;
  final int itemCount;
  final bool isPricing;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md + MediaQuery.viewPaddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.semantic.border)),
      ),
      child: PrimaryButton(
        label: AppStrings.proceedToCheckout,
        onPressed: isPricing ? null : onCheckout,
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
              style: context.text.labelMedium!.copyWith(color: context.colors.surface.withValues(alpha: 0.7)),
            ),
            Text(
              total.asCurrency,
              style: context.text.price.copyWith(color: context.colors.surface),
            ),
          ],
        ),
      ),
    );
  }
}
