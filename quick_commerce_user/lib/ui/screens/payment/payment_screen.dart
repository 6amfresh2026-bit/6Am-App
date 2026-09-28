import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_durations.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/extensions/num_extensions.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../di/app_providers.dart';
import '../../../di/usecase_providers.dart';
import '../../../domain/model/order.dart';
import '../../../domain/model/payment_method.dart';
import '../../../domain/usecase/verify_payment_usecase.dart';
import '../../../navigation/route_paths.dart';
import '../../common/widgets/buttons/primary_button.dart';
import '../../common/widgets/buttons/secondary_button.dart';
import '../../common/widgets/feedback/app_bottom_sheet.dart';
import '../../common/widgets/feedback/app_dialog.dart';

/// Where the payment attempt currently stands.
enum PaymentPhase { idle, processing, success, failed }

/// Gateway handoff.
///
/// Opens the Razorpay sheet with the parameters the backend minted at order
/// creation, then hands the result to `verify-payment`. Nothing here decides
/// whether the payment succeeded — the backend re-checks the signature and the
/// captured amount before the order is marked paid.
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.placedOrder});

  final PlacedOrder placedOrder;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  PaymentPhase _phase = PaymentPhase.idle;
  String _error = '';

  @override
  void initState() {
    super.initState();
    if (widget.placedOrder.needsGatewayPayment) {
      Future.microtask(_pay);
    } else if (widget.placedOrder.order.paymentMethod.isOnline) {
      // An online order with no Razorpay parameters means the gateway is not
      // configured on the backend. The order is sitting in pending_payment and
      // was never charged — say so instead of showing a success screen.
      _phase = PaymentPhase.failed;
      _error = 'Online payment is unavailable right now. '
          'Cancel and try Cash on Delivery.';
    } else {
      // Cash and wallet orders are already settled server-side at creation.
      // Their "order placed" pulse fires here; gateway orders get theirs on
      // payment success instead, so every order buzzes exactly once.
      AppHaptics.success();
      Future.microtask(_complete);
    }
  }

  Future<void> _pay() async {
    setState(() {
      _phase = PaymentPhase.processing;
      _error = '';
    });

    try {
      final order = await ref.read(verifyPaymentUseCaseProvider)(
        widget.placedOrder,
        customer: ref.read(authProvider).user,
      );
      if (!mounted) return;
      AppHaptics.success();
      setState(() => _phase = PaymentPhase.success);
      await Future<void>.delayed(AppDurations.medium);
      if (mounted) _complete(order: order);
    } on PaymentCancelledByUser {
      // Not a failure: the sheet was dismissed. The order stays in
      // pending_payment, so offer the same retry / cancel choice.
      if (!mounted) return;
      setState(() {
        _phase = PaymentPhase.failed;
        _error = 'Payment was cancelled. Your order is still waiting.';
      });
    } on PaymentDeclined catch (e) {
      if (!mounted) return;
      AppHaptics.error();
      setState(() {
        _phase = PaymentPhase.failed;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      AppHaptics.error();
      setState(() {
        _phase = PaymentPhase.failed;
        _error = ErrorMapper.toFailure(e).message;
      });
    }
  }

  /// Clears the cart and hands off to the success screen.
  void _complete({Order? order}) {
    ref.read(cartProvider.notifier).clear();
    context.go(
      RoutePaths.orderSuccess,
      extra: order ?? widget.placedOrder.order,
    );
  }

  Future<void> _abandon() async {
    final confirmed = await AppDialog.confirm(
      context,
      icon: Icons.cancel_outlined,
      title: 'Cancel this payment?',
      message:
          'Your order will not be placed and your cart will be kept as it is.',
      confirmLabel: 'Cancel payment',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(verifyPaymentUseCaseProvider).abandon(widget.placedOrder);
    } catch (_) {
      // The order stays in pending_payment server-side and expires there.
    }
    if (mounted) context.go(RoutePaths.cart);
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.placedOrder.order;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PhaseIndicator(phase: _phase),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  switch (_phase) {
                    PaymentPhase.processing => 'Completing your payment',
                    PaymentPhase.success => 'Payment successful',
                    PaymentPhase.failed => 'Payment could not be completed',
                    PaymentPhase.idle => 'Preparing your payment',
                  },
                  textAlign: TextAlign.center,
                  style: context.text.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _phase == PaymentPhase.failed
                      ? _error
                      : 'Paying ${order.pricing.total.asCurrency} via '
                          '${order.paymentMethod.label}',
                  textAlign: TextAlign.center,
                  style: context.text.bodyLarge!
                      .copyWith(color: context.semantic.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: context.semantic.surfaceAlt,
                    borderRadius: AppRadii.rLg,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 18,
                        color: context.semantic.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Order ${order.displayId}',
                          style: context.text.titleSmall,
                        ),
                      ),
                      Text(
                        order.pricing.total.asCurrency,
                        style: context.text.price,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_phase == PaymentPhase.failed) ...[
                  PrimaryButton(
                    label: 'Try again',
                    icon: Icons.refresh_rounded,
                    onPressed: _pay,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SecondaryButton(
                    label: 'Cancel payment',
                    expand: true,
                    destructive: true,
                    onPressed: _abandon,
                  ),
                ] else if (_phase == PaymentPhase.processing)
                  Text(
                    'Do not close this screen',
                    style: context.text.bodySmall,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhaseIndicator extends StatelessWidget {
  const _PhaseIndicator({required this.phase});

  final PaymentPhase phase;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (phase) {
      PaymentPhase.failed => (context.semantic.danger, Icons.close_rounded),
      PaymentPhase.success => (context.semantic.success, Icons.check_rounded),
      _ => (context.colors.primary, Icons.lock_rounded),
    };

    return SizedBox(
      height: 128,
      width: 128,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (phase == PaymentPhase.processing || phase == PaymentPhase.idle)
            SizedBox(
              height: 128,
              width: 128,
              child: CircularProgressIndicator(strokeWidth: 3, color: color),
            ),
          TweenAnimationBuilder<double>(
            key: ValueKey(phase),
            tween: Tween(begin: 0.7, end: 1),
            duration: AppDurations.medium,
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              height: 86,
              width: 86,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Payment method chooser, shared by checkout and any retry flow.
class PaymentMethodSheet extends StatelessWidget {
  const PaymentMethodSheet({super.key, required this.selected});

  final PaymentMethod selected;

  static Future<PaymentMethod?> show(
    BuildContext context, {
    required PaymentMethod selected,
  }) =>
      AppBottomSheet.show<PaymentMethod>(
        context,
        title: 'Choose how to pay',
        subtitle: 'Online payments are confirmed instantly',
        child: PaymentMethodSheet(selected: selected),
      );

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl + MediaQuery.viewPaddingOf(context).bottom,
      ),
      itemCount: PaymentMethod.values.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final method = PaymentMethod.values[index];
        final isSelected = method == selected;

        return GestureDetector(
          onTap: () => Navigator.of(context).pop(method),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: isSelected
                  ? context.colors.primary.withValues(alpha: 0.07)
                  : context.colors.surface,
              borderRadius: AppRadii.rMd,
              border: Border.all(
                color:
                    isSelected ? context.colors.primary : context.semantic.border,
              ),
            ),
            child: Row(
              children: [
                Icon(_icon(method), size: 20, color: context.colors.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(method.label, style: context.text.titleMedium),
                      Text(method.subtitle, style: context.text.bodySmall),
                    ],
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: isSelected
                      ? context.colors.primary
                      : context.semantic.border,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static IconData _icon(PaymentMethod method) => switch (method) {
        PaymentMethod.upi => Icons.account_balance_rounded,
        PaymentMethod.card => Icons.credit_card_rounded,
        PaymentMethod.qr => Icons.qr_code_2_rounded,
        PaymentMethod.wallet => Icons.account_balance_wallet_rounded,
        PaymentMethod.cash => Icons.payments_rounded,
      };
}
