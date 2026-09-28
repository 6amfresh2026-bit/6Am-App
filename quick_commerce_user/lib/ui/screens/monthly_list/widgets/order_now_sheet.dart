import 'package:flutter/material.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/model/address.dart';
import '../../../../domain/model/payment_method.dart';
import '../../../common/widgets/buttons/primary_button.dart';
import '../../../common/widgets/feedback/app_bottom_sheet.dart';

/// The address and payment method chosen for a one-off order.
class OrderNowChoice {
  const OrderNowChoice({required this.address, required this.method});

  final Address address;
  final PaymentMethod method;
}

/// Confirmation step for "order this monthly list now".
///
/// Deliberately small: the backend re-prices and re-validates the whole basket
/// server-side, so this only collects what the endpoint needs — where it goes
/// and how it is paid. The full total is shown on the payment screen that
/// follows, from the server's own figures rather than a local estimate.
abstract final class OrderNowSheet {
  /// Methods the monthly-list order endpoint accepts. `razorpay_qr` is absent
  /// because that path never mints a gateway order.
  static const _methods = [
    PaymentMethod.cash,
    PaymentMethod.upi,
    PaymentMethod.card,
    PaymentMethod.wallet,
  ];

  static Future<OrderNowChoice?> show(
    BuildContext context, {
    required Address address,
  }) =>
      AppBottomSheet.show<OrderNowChoice>(
        context,
        title: 'Order this month',
        subtitle: 'Delivering to ${address.shortLine}',
        child: _OrderNowBody(address: address, methods: _methods),
      );
}

class _OrderNowBody extends StatefulWidget {
  const _OrderNowBody({required this.address, required this.methods});

  final Address address;
  final List<PaymentMethod> methods;

  @override
  State<_OrderNowBody> createState() => _OrderNowBodyState();
}

class _OrderNowBodyState extends State<_OrderNowBody> {
  PaymentMethod _method = PaymentMethod.cash;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment method', style: context.text.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        ...widget.methods.map(
          (method) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _MethodTile(
              method: method,
              isSelected: method == _method,
              onTap: () => setState(() => _method = method),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: context.semantic.surfaceAlt,
            borderRadius: AppRadii.rMd,
          ),
          child: Text(
            'Items are re-priced at today’s rates. You will see the final '
            'total before paying.',
            style: context.text.bodySmall?.copyWith(
              color: context.semantic.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Continue',
          onPressed: () => Navigator.of(context).pop(
            OrderNowChoice(address: widget.address, method: _method),
          ),
        ),
      ],
    );
  }
}

/// Matches the payment screen's own method tile so the two selectors look and
/// behave the same.
class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.method,
    required this.isSelected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? context.colors.primary.withValues(alpha: 0.07)
              : context.colors.surface,
          borderRadius: AppRadii.rMd,
          border: Border.all(
            color: isSelected ? context.colors.primary : context.semantic.border,
          ),
        ),
        child: Row(
          children: [
            Icon(_icon, size: 20, color: context.colors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(method.label, style: context.text.titleSmall),
                  Text(
                    method.subtitle,
                    style: context.text.bodySmall?.copyWith(
                      color: context.semantic.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color:
                  isSelected ? context.colors.primary : context.semantic.border,
            ),
          ],
        ),
      ),
    );
  }

  IconData get _icon => switch (method) {
        PaymentMethod.upi => Icons.account_balance_rounded,
        PaymentMethod.card => Icons.credit_card_rounded,
        PaymentMethod.qr => Icons.qr_code_2_rounded,
        PaymentMethod.wallet => Icons.account_balance_wallet_rounded,
        PaymentMethod.cash => Icons.payments_rounded,
      };
}
