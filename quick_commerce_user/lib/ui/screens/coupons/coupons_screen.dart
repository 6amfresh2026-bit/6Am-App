import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/extensions/num_extensions.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../di/app_providers.dart';
import '../../../di/service_providers.dart';
import '../../../domain/model/coupon.dart';
import '../../../domain/usecase/apply_coupon_usecase.dart';
import '../../common/widgets/buttons/secondary_button.dart';
import '../../common/widgets/feedback/app_toast.dart';
import '../../common/widgets/inputs/app_text_field.dart';
import '../../common/widgets/loaders/list_skeleton.dart';
import '../../common/widgets/states/empty_state_widget.dart';
import '../../common/widgets/states/error_state_widget.dart';
import 'coupons_provider.dart';

class CouponsScreen extends ConsumerStatefulWidget {
  const CouponsScreen({super.key});

  @override
  ConsumerState<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends ConsumerState<CouponsScreen> {
  final _codeController = TextEditingController();
  String? _applyingId;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _apply(Coupon coupon) async {
    setState(() => _applyingId = coupon.id);
    final outcome = await ref.read(cartProvider.notifier).applyCoupon(coupon);
    if (!mounted) return;
    setState(() => _applyingId = null);

    switch (outcome) {
      case CouponApplied(:final savings):
        AppToast.success(context, 'Saved ${savings.asCurrency} with ${coupon.code}');
        context.pop();
      case CouponRejected(:final reason):
        AppToast.error(context, reason);
    }
  }

  Future<void> _applyTypedCode(List<Coupon> coupons) async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    final match = coupons.where((c) => c.code.toUpperCase() == code).firstOrNull;
    if (match == null) {
      AppToast.error(context, 'We could not find the coupon "$code"');
      return;
    }
    await _apply(match);
  }

  @override
  Widget build(BuildContext context) {
    final coupons = ref.watch(couponsProvider);
    final cart = ref.watch(cartProvider).cart;
    final eligibility = ref.watch(couponEligibilityServiceProvider);
    final appliedCode = cart.pricing.couponCode ?? cart.appliedCoupon?.code;

    return Scaffold(
      appBar: AppBar(title: const Text('Offers & coupons')),
      body: SafeArea(
        child: coupons.when(
          loading: () => const ListSkeleton(count: 5, height: 108),
          error: (error, _) => ErrorStateWidget(
            failure: ErrorMapper.toFailure(error),
            onRetry: () => ref.invalidate(couponsProvider),
          ),
          data: (items) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _codeController,
                      hint: 'Enter a coupon code',
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  SecondaryButton(
                    label: 'Apply',
                    tonal: false,
                    onPressed: () => _applyTypedCode(items),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              if (items.isEmpty)
                const EmptyStateWidget(
                  icon: Icons.local_offer_outlined,
                  title: 'No offers right now',
                  message:
                      'New coupons land here regularly — check back before your next order.',
                  compact: true,
                )
              else
                for (final coupon in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _CouponCard(
                      coupon: coupon,
                      eligibility: eligibility.evaluate(coupon, cart),
                      isApplied: appliedCode == coupon.code,
                      isApplying: _applyingId == coupon.id,
                      estimatedSaving: coupon.estimatedDiscountOn(
                        cart.pricing.subtotal > 0
                            ? cart.pricing.subtotal
                            : cart.provisionalSubtotal,
                      ),
                      onApply: () => _apply(coupon),
                      onRemove: () =>
                          ref.read(cartProvider.notifier).removeCoupon(),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({
    required this.coupon,
    required this.eligibility,
    required this.isApplied,
    required this.isApplying,
    required this.estimatedSaving,
    required this.onApply,
    required this.onRemove,
  });

  final Coupon coupon;
  final CouponEligibility eligibility;
  final bool isApplied;
  final bool isApplying;
  final double estimatedSaving;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final enabled = eligibility.isEligible;

    return Opacity(
      opacity: enabled ? 1 : 0.62,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isApplied ? context.semantic.successSoft : context.colors.surface,
          borderRadius: AppRadii.rLg,
          border: Border.all(
            color: isApplied ? context.semantic.success : context.semantic.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.10),
                    borderRadius: AppRadii.rSm,
                    border: Border.all(
                      color: context.colors.primary.withValues(alpha: 0.4),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Text(
                    coupon.code,
                    style: context.text.labelLarge!
                        .copyWith(color: context.colors.primary),
                  ),
                ),
                const Spacer(),
                if (isApplied)
                  TextButton(
                    onPressed: onRemove,
                    child: Text(
                      'Remove',
                      style: context.text.labelMedium!
                          .copyWith(color: context.semantic.danger),
                    ),
                  )
                else if (isApplying)
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                else
                  TextButton(
                    onPressed: enabled ? onApply : null,
                    child: Text(
                      'Apply',
                      style: context.text.labelMedium!.copyWith(
                        color: enabled
                            ? context.colors.primary
                            : context.semantic.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(coupon.title, style: context.text.titleMedium),
            if (coupon.sellerName.isNotEmpty)
              Text(coupon.sellerName, style: context.text.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            if (!enabled)
              Text(
                eligibility.reason,
                style: context.text.labelMedium!
                    .copyWith(color: context.semantic.warning),
              )
            else if (estimatedSaving > 0)
              Text(
                'Saves about ${estimatedSaving.asCurrency} on this order',
                style: context.text.labelMedium!
                    .copyWith(color: context.semantic.success),
              ),
            if (coupon.expiresAt != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Valid until ${_date(coupon.expiresAt!)}',
                style: context.text.bodySmall!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _date(DateTime time) =>
      '${time.day.toString().padLeft(2, '0')}/'
      '${time.month.toString().padLeft(2, '0')}/${time.year}';
}
