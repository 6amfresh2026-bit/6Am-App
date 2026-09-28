import 'package:flutter/material.dart';

import '../../../../domain/model/category.dart';
import '../../../common/widgets/loaders/shimmer_box.dart';
import '../../../common/widgets/misc/app_network_image.dart';
import '../../../common/widgets/misc/section_header.dart';
import '../../../../core/theme/app_theme.dart';

/// "Shop by Category" tiles, backed by the real top-level category list.
class ShopByCategoryRow extends StatelessWidget {
  const ShopByCategoryRow({
    super.key,
    this.categories = const [],
    this.isLoading = false,
    this.onCategoryTap,
    this.onSeeAll,
  });

  final List<Category> categories;
  final bool isLoading;
  final ValueChanged<String>? onCategoryTap;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (!isLoading && categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Shop by Category', onSeeAll: onSeeAll),
        SizedBox(
          height: 125,
          child: categories.isEmpty
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: 4,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, _) => const Column(
                    children: [
                      ShimmerBox(width: 84, height: 76),
                      SizedBox(height: 4),
                      ShimmerBox(width: 64, height: 10),
                    ],
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = categories[index];
                    return GestureDetector(
                      onTap: () => onCategoryTap?.call(item.id),
                      child: SizedBox(
                        width: 84,
                        child: Column(
                          children: [
                            Container(
                              height: 76,
                              width: 84,
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: context.semantic.surfaceAlt,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: AppNetworkImage(
                                url: item.imageUrl,
                                fit: BoxFit.contain,
                                fallbackIcon: Icons.category_rounded,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.name,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodySmall!.copyWith(fontWeight: FontWeight.w800, color: context.colors.onSurface, fontSize: 10.5),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
