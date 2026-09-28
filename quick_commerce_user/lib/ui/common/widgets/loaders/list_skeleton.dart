import 'package:flutter/material.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import 'shimmer_box.dart';

/// Generic row skeleton for orders, addresses, notifications and coupons.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({
    super.key,
    this.count = 5,
    this.height = 84,
    this.hasLeading = true,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final int count;
  final double height;
  final bool hasLeading;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, _) => Container(
        height: height,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadii.rLg,
          border: Border.all(color: context.semantic.border),
        ),
        child: Row(
          children: [
            if (hasLeading) ...[
              const ShimmerBox(width: 52, height: 52, radius: AppRadii.rMd),
              const SizedBox(width: AppSpacing.md),
            ],
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShimmerBox(width: 140, height: 12),
                  SizedBox(height: AppSpacing.sm),
                  ShimmerBox(width: 90, height: 10),
                ],
              ),
            ),
            const ShimmerBox(width: 48, height: 14),
          ],
        ),
      ),
    );
  }
}

/// Category-grid skeleton for the categories screen and home strip.
class CategoryGridSkeleton extends StatelessWidget {
  const CategoryGridSkeleton({super.key, this.count = 8, this.columns = 4});

  final int count;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: AppSpacing.lg,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (_, _) => const Column(
        children: [
          ShimmerBox(height: 62, width: 62, radius: AppRadii.rLg),
          SizedBox(height: AppSpacing.sm),
          ShimmerBox(width: 48, height: 9),
        ],
      ),
    );
  }
}
