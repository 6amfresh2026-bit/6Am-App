import 'package:flutter/material.dart';

import '../../../../../core/extensions/string_extensions.dart';
import '../../../../../core/theme/app_radii.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../domain/model/review.dart';
import '../../../../common/widgets/buttons/secondary_button.dart';
import '../../../../common/widgets/misc/rating_stars.dart';

/// Aggregate rating, star histogram and the individual reviews.
class ReviewsSection extends StatelessWidget {
  const ReviewsSection({
    super.key,
    required this.summary,
    required this.reviews,
    required this.canWrite,
    required this.onWrite,
  });

  final RatingSummary summary;
  final List<Review> reviews;
  final bool canWrite;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary.total == 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: context.semantic.surfaceAlt,
              borderRadius: AppRadii.rLg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No reviews yet', style: context.text.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  canWrite
                      ? 'You have ordered this before — tell others what you thought.'
                      : 'Reviews appear here once customers rate a delivered order.',
                  style: context.text.bodyMedium,
                ),
              ],
            ),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Text(
                    summary.average.toStringAsFixed(1),
                    style: context.text.displaySmall,
                  ),
                  RatingStars(rating: summary.average, showValue: false),
                  const SizedBox(height: AppSpacing.xs),
                  Text('${summary.total} ratings', style: context.text.bodySmall),
                ],
              ),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                child: Column(
                  children: [
                    for (var star = 5; star >= 1; star--)
                      _HistogramRow(
                        star: star,
                        fraction: summary.fractionFor(star),
                        count: summary.distribution[star] ?? 0,
                      ),
                  ],
                ),
              ),
            ],
          ),
        if (canWrite) ...[
          const SizedBox(height: AppSpacing.lg),
          SecondaryButton(
            label: 'Write a review',
            icon: Icons.rate_review_outlined,
            expand: true,
            onPressed: onWrite,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        for (final review in reviews.take(6)) _ReviewTile(review: review),
      ],
    );
  }
}

class _HistogramRow extends StatelessWidget {
  const _HistogramRow({
    required this.star,
    required this.fraction,
    required this.count,
  });

  final int star;
  final double fraction;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            child: Text('$star', style: context.text.bodySmall),
          ),
          Icon(Icons.star_rounded, size: 12, color: context.semantic.accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: context.semantic.surfaceAlt,
                valueColor:
                    AlwaysStoppedAnimation(context.semantic.success),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 26,
            child: Text(
              '$count',
              textAlign: TextAlign.end,
              style: context.text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: context.colors.primary.withValues(alpha: 0.12),
            child: Text(
              review.authorName.initials,
              style: context.text.labelMedium!
                  .copyWith(color: context.colors.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        review.authorName,
                        style: context.text.titleSmall,
                      ),
                    ),
                    RatingStars(rating: review.rating, size: 11),
                  ],
                ),
                Text(
                  _relative(review.createdAt),
                  style: context.text.bodySmall!,
                ),
                if (review.comment.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(review.comment, style: context.text.bodyMedium),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _relative(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 30) return '${diff.inDays ~/ 30} months ago';
    if (diff.inDays > 0) return '${diff.inDays} days ago';
    if (diff.inHours > 0) return '${diff.inHours} hours ago';
    return 'Just now';
  }
}
