import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Compact star rating. Half stars are rendered, because a 4.3 shown as 4 is a
/// small lie repeated on every card.
class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.rating,
    this.count,
    this.size = 13,
    this.showValue = true,
  });

  final double rating;
  final int? count;
  final double size;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    if (rating <= 0) return const SizedBox.shrink();

    return Semantics(
      label: '$rating out of 5${count != null ? ', $count ratings' : ''}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: size + 2, color: context.semantic.warning),
          if (showValue) ...[
            const SizedBox(width: 2),
            Text(
              rating.toStringAsFixed(1),
              style: context.text.labelMedium!
                  .copyWith(color: context.colors.onSurface),
            ),
          ],
          if (count != null && count! > 0) ...[
            const SizedBox(width: 3),
            Text(
              '($count)',
              style: context.text.bodySmall!.copyWith(fontSize: size - 2),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tappable 1–5 star input used by the review and order-rating forms.
class RatingInput extends StatelessWidget {
  const RatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
    this.size = 34,
  });

  final int rating;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final value = index + 1;
        return Semantics(
          button: true,
          label: 'Rate $value out of 5',
          child: IconButton(
            onPressed: () => onChanged(value),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            constraints: const BoxConstraints(),
            icon: Icon(
              value <= rating ? Icons.star_rounded : Icons.star_border_rounded,
              size: size,
              color: value <= rating
                  ? context.semantic.warning
                  : context.semantic.border,
            ),
          ),
        );
      }),
    );
  }
}
