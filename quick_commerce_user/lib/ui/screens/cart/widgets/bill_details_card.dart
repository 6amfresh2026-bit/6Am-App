import 'package:flutter/material.dart';

import '../../../../core/extensions/num_extensions.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/service/cart_pricing_service.dart';
import '../../../common/widgets/loaders/shimmer_box.dart';

/// Itemised bill. Every figure is rendered exactly as the server priced it —
/// this widget performs no arithmetic of its own.
class BillDetailsCard extends StatelessWidget {
  const BillDetailsCard({
    super.key,
    required this.lines,
    required this.savings,
    this.isPricing = false,
  });

  final List<BillLine> lines;
  final double savings;
  final bool isPricing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: context.semantic.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Bill details', style: context.text.titleLarge)),
              if (isPricing)
                const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final line in lines) ...[
            if (line.isTotal) ...[
              const SizedBox(height: AppSpacing.sm),
              Divider(color: context.semantic.border),
              const SizedBox(height: AppSpacing.sm),
            ],
            _BillRow(line: line, isPricing: isPricing),
            if (!line.isTotal) const SizedBox(height: AppSpacing.md),
          ],
          if (savings > 0) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: context.semantic.successSoft,
                borderRadius: AppRadii.rSm,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.celebration_rounded,
                    size: 15,
                    color: context.semantic.success,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'You saved ${savings.asCurrency} on this order',
                    style: context.text.labelMedium!
                        .copyWith(color: context.semantic.success),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({required this.line, required this.isPricing});

  final BillLine line;
  final bool isPricing;

  @override
  Widget build(BuildContext context) {
    final valueStyle = line.isTotal
        ? context.text.priceLarge
        : line.isDiscount
            ? context.text.titleSmall!.copyWith(color: context.semantic.success)
            : context.text.titleSmall!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.label,
                style: line.isTotal
                    ? context.text.titleLarge
                    : context.text.bodyMedium,
              ),
              if (line.note.isNotEmpty)
                Text(
                  line.note,
                  style: context.text.bodySmall!,
                ),
            ],
          ),
        ),
        if (isPricing && !line.isTotal)
          const ShimmerBox(width: 44, height: 12)
        else if (line.isFree)
          Text(
            'FREE',
            style: context.text.badgeLabel.copyWith(color: context.semantic.success),
          )
        else
          Text(
            '${line.isDiscount ? '− ' : ''}${line.amount.asCurrency}',
            style: valueStyle,
          ),
      ],
    );
  }
}
