import 'package:flutter/material.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/model/order_status.dart';

/// Colour-coded status pill used on the orders list and details header.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      _ when status.isCancelled => (
          context.semantic.dangerSoft,
          context.semantic.danger,
        ),
      OrderStatus.delivered => (
          context.semantic.successSoft,
          context.semantic.success,
        ),
      OrderStatus.pendingPayment => (
          context.semantic.warningSoft,
          context.semantic.warning,
        ),
      _ => (
          context.colors.primary.withValues(alpha: 0.10),
          context.colors.primary,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(color: background, borderRadius: AppRadii.rPill),
      child: Text(
        status.label,
        style: context.text.badgeLabel.copyWith(color: foreground),
      ),
    );
  }
}
