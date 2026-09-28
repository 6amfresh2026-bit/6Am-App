import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_durations.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/num_extensions.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../common/delivery_promise.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../di/app_providers.dart';
import '../../../di/service_providers.dart';
import '../../../navigation/route_paths.dart';
import '../../common/widgets/buttons/primary_button.dart';
import '../../common/widgets/feedback/app_toast.dart';
import '../../common/widgets/misc/app_network_image.dart';
import '../../common/widgets/states/offline_banner.dart';
import '../cart/widgets/bill_details_card.dart';
import '../payment/payment_screen.dart';
import 'checkout_provider.dart';
import 'checkout_state.dart';
import 'widgets/checkout_section_card.dart';

class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(checkoutProvider);
    final cartState = ref.watch(cartProvider);
    final cart = cartState.cart;
    final pricingService = ref.watch(cartPricingServiceProvider);

    if (cart.isEmpty) {
      // Cart emptied from another screen — do not strand the user here.
      return const _EmptyCartRedirect();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      bottomNavigationBar: _PayBar(
        total: cart.effectiveTotal,
        isPricing: cartState.isPricing,
        isPlacing: state.isPlacing,
        onPay: () => _proceed(context, ref),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          children: [
            const OfflineBanner(),
            _AddressCard(shake: state.shakeAddressCard),
            // No window picker: a basket is for now. Recurring morning rounds
            // are a standing arrangement set up as a subscription, not chosen
            // per basket, so this states the promise rather than offering a
            // choice the backend would not honour from here.
            CheckoutSectionCard(
              icon: Icons.bolt_rounded,
              title: 'Delivery time',
              subtitle: DeliveryPromise.label(
                cart.pricing.deliveryPromiseMinutes,
              ),
            ),
            CheckoutSectionCard(
              icon: Icons.account_balance_wallet_rounded,
              title: 'Payment method',
              subtitle: state.paymentMethod.label,
              actionLabel: AppStrings.change,
              onAction: () async {
                final method = await PaymentMethodSheet.show(
                  context,
                  selected: state.paymentMethod,
                );
                if (method != null) {
                  ref.read(checkoutProvider.notifier).setPaymentMethod(method);
                }
              },
            ),
            _OrderSummary(expanded: state.expandedSummary),
            _Preferences(state: state, isGrocery: cart.isGrocery),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: BillDetailsCard(
                lines: pricingService.billLines(cart),
                savings: cart.totalSavings,
                isPricing: cartState.isPricing,
              ),
            ),
            if (state.failure != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  state.failure!.message,
                  style: context.text.bodyMedium!
                      .copyWith(color: context.colors.error),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _proceed(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authProvider).user;
    final placed = await ref.read(checkoutProvider.notifier).placeOrder(
          name: user?.name,
          phone: user?.phone,
        );

    if (!context.mounted) return;

    if (placed == null) {
      final issues = ref.read(checkoutProvider).issues;
      AppToast.error(
        context,
        issues.isEmpty
            ? ref.read(checkoutProvider).failure?.message ??
                AppStrings.somethingWentWrong
            : issues.first.message,
      );
      return;
    }

    context.push(RoutePaths.payment, extra: placed);
  }
}

class _AddressCard extends ConsumerStatefulWidget {
  const _AddressCard({required this.shake});

  final bool shake;

  @override
  ConsumerState<_AddressCard> createState() => _AddressCardState();
}

class _AddressCardState extends ConsumerState<_AddressCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.slow,
  );

  @override
  void didUpdateWidget(_AddressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shake && !oldWidget.shake) {
      _controller.forward(from: 0);
      ref.read(checkoutProvider.notifier).consumeShake();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final address = ref.watch(selectedAddressProvider);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Damped sine: three shakes that decay, not a jitter that never settles.
        final offset = _controller.isAnimating
            ? 10 *
                (1 - _controller.value) *
                math.sin(_controller.value * 3 * 2 * math.pi)
            : 0.0;
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: CheckoutSectionCard(
        icon: Icons.location_on_rounded,
        title: address == null ? 'No address selected' : 'Deliver to ${address.label.wireValue}',
        subtitle: address?.fullLine ?? 'Choose where we should deliver',
        actionLabel: address == null ? 'Select' : AppStrings.change,
        highlight: address == null,
        onAction: () => context.push(RoutePaths.addresses),
      ),
    );
  }
}

class _OrderSummary extends ConsumerWidget {
  const _OrderSummary({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider).cart;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: context.semantic.border),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: ref.read(checkoutProvider.notifier).toggleSummary,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${cart.itemCount} ${cart.itemCount == 1 ? 'item' : 'items'} '
                    'from ${cart.sellerName.isEmpty ? 'your store' : cart.sellerName}',
                    style: context.text.titleMedium,
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: context.semantic.textSecondary,
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: AppDurations.medium,
            crossFadeState:
                expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                const SizedBox(height: AppSpacing.md),
                for (final item in cart.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: AppRadii.rSm,
                          child: AppNetworkImage(
                            url: item.product.imageUrl,
                            height: 38,
                            width: 38,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.bodyLarge,
                              ),
                              Text(
                                '${item.variantLabel} · ×${item.quantity}',
                                style: context.text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(item.lineTotal.asCurrency,
                            style: context.text.titleSmall),
                      ],
                    ),
                  ),
              ],
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _Preferences extends ConsumerWidget {
  const _Preferences({required this.state, required this.isGrocery});

  final CheckoutState state;
  final bool isGrocery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: context.semantic.border),
      ),
      child: Column(
        children: [
          // A shop has no cutlery to send, so the toggle is hidden rather than
          // offered and ignored.
          if (!isGrocery) ...[
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: state.sendCutlery,
              onChanged: ref.read(checkoutProvider.notifier).setSendCutlery,
              title: Text('Send cutlery', style: context.text.titleMedium),
              subtitle: Text(
                'Skip it and we will save some plastic',
                style: context.text.bodySmall,
              ),
            ),
            Divider(color: context.semantic.border, height: 1),
          ],
          // Off by default. Saying yes here is what lets the shop swap an item
          // it cannot supply; without it a missing item is simply refunded.
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: state.allowSubstitutes,
            onChanged: ref.read(checkoutProvider.notifier).setAllowSubstitutes,
            title: Text(
              'Allow replacements',
              style: context.text.titleMedium,
            ),
            subtitle: Text(
              state.allowSubstitutes
                  ? 'We may swap something out of stock for a similar item'
                  : 'Anything out of stock is refunded, never swapped',
              style: context.text.bodySmall,
            ),
          ),
          Divider(color: context.semantic.border, height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.edit_note_rounded,
              color: context.semantic.textSecondary,
            ),
            title: Text(
              state.instructions.isEmpty
                  ? (isGrocery
                      ? 'Add a delivery note'
                      : 'Add delivery instructions')
                  : state.instructions,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyLarge,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _editInstructions(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _editInstructions(BuildContext context, WidgetRef ref) async {
    final controller =
        TextEditingController(text: ref.read(checkoutProvider).instructions);

    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delivery instructions', style: context.text.headlineSmall),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: 'e.g. Leave at the door, ring the bell once',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Save',
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            ),
          ],
        ),
      ),
    );

    if (value != null) {
      ref.read(checkoutProvider.notifier).setInstructions(value);
    }
    controller.dispose();
  }
}

class _PayBar extends StatelessWidget {
  const _PayBar({
    required this.total,
    required this.isPricing,
    required this.isPlacing,
    required this.onPay,
  });

  final double total;
  final bool isPricing;
  final bool isPlacing;
  final VoidCallback onPay;

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
        label: AppStrings.proceedToPay,
        isLoading: isPlacing,
        onPressed: isPricing || total <= 0 ? null : onPay,
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.grandTotal,
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

/// Bounces back to Home when the cart empties while checkout is open.
class _EmptyCartRedirect extends StatefulWidget {
  const _EmptyCartRedirect();

  @override
  State<_EmptyCartRedirect> createState() => _EmptyCartRedirectState();
}

class _EmptyCartRedirectState extends State<_EmptyCartRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(RoutePaths.home);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}
