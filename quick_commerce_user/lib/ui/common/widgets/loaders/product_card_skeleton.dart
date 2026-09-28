import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import 'shimmer_box.dart';

/// Mirrors the real product card's layout so content does not jump on load.
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key, this.width = AppDimens.productCardWidth});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: context.semantic.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ShimmerBox(
              height: double.infinity,
              width: double.infinity,
              radius: AppRadii.rMd,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          ShimmerBox(width: 44, height: 9),
          SizedBox(height: 4),
          ShimmerBox(width: double.infinity, height: 10),
          SizedBox(height: 4),
          ShimmerBox(width: 70, height: 10),
          SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: ShimmerBox(width: 38, height: 14)),
              SizedBox(width: 4),
              ShimmerBox(width: 50, height: 28, radius: AppRadii.rSm),
            ],
          ),
        ],
      ),
    );
  }
}

/// Horizontal strip of product skeletons, used by home sections.
class ProductRowSkeleton extends StatelessWidget {
  const ProductRowSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 258,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (_, _) => const ProductCardSkeleton(),
      ),
    );
  }
}

/// Grid of product skeletons, used by listing and search.
class ProductGridSkeleton extends StatelessWidget {
  const ProductGridSkeleton({super.key, this.count = 6, this.columns = 2});

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
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.58,
      ),
      itemBuilder: (_, _) => const ProductCardSkeleton(width: double.infinity),
    );
  }
}
