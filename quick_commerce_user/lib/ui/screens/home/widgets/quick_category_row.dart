import 'package:flutter/material.dart';

import '../../../../domain/model/category.dart';
import '../../../common/widgets/loaders/shimmer_box.dart';
import '../../../common/widgets/misc/app_network_image.dart';
import '../../../../core/theme/app_theme.dart';

/// The icon strip at the very top of home.
///
/// "All" is a fixed entry into the category tree; every other tile is a real
/// top-level category from `/food/restaurant/categories/public`.
class QuickCategoryRow extends StatelessWidget {
  const QuickCategoryRow({
    super.key,
    this.categories = const [],
    this.isLoading = false,
    this.onCategoryTap,
    this.onAllTap,
  });

  final List<Category> categories;
  final bool isLoading;

  /// Receives a real category id.
  final ValueChanged<String>? onCategoryTap;

  /// "All" and the trailing "More" tile both open the full category list.
  final VoidCallback? onAllTap;

  /// Tiles beyond this spill into the "More" entry.
  static const _maxTiles = 5;

  @override
  Widget build(BuildContext context) {
    if (isLoading && categories.isEmpty) return const _QuickCategorySkeleton();
    if (categories.isEmpty) return const SizedBox.shrink();

    final shown = categories.take(_maxTiles).toList();
    // "All" leads, real categories follow, "More" only when some were cut.
    final hasMore = categories.length > _maxTiles;
    final itemCount = shown.length + (hasMore ? 2 : 1);

    return SizedBox(
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _Tile(
              label: 'All',
              icon: Icons.grid_view_rounded,
              isAll: true,
              onTap: onAllTap,
            );
          }
          if (hasMore && index == itemCount - 1) {
            return _Tile(
              label: 'More',
              icon: Icons.keyboard_arrow_down_rounded,
              isPill: true,
              onTap: onAllTap,
            );
          }
          final cat = shown[index - 1];
          return _Tile(
            label: cat.name,
            imageUrl: cat.imageUrl,
            icon: Icons.category_rounded,
            onTap: () => onCategoryTap?.call(cat.id),
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.icon,
    this.imageUrl = '',
    this.isAll = false,
    this.isPill = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final String imageUrl;
  final bool isAll;
  final bool isPill;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.trim().isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            padding: hasImage ? const EdgeInsets.all(3) : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: isAll ? const Color(0xFF43B5A8) : Colors.white,
              // color: isAll ? const Color(0xFFFFC107) : Colors.white,
              shape: isAll || isPill ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: isAll
                  ? BorderRadius.circular(14)
                  : (isPill ? BorderRadius.circular(25) : null),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: hasImage
                ? ClipOval(
                    child: AppNetworkImage(
                      url: imageUrl,
                      width: 44,
                      height: 44,
                      fallbackIcon: icon,
                    ),
                  )
                : Icon(
                    icon,
                    size: 24,
                    color: isAll ? Colors.white : const Color(0xFF1F2937),
                  ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: 58,
            child: Text(
              label,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall!.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 10.5,
                color: context.colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCategorySkeleton extends StatelessWidget {
  const _QuickCategorySkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, _) => const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShimmerBox(width: 56, height: 56),
            SizedBox(height: 4),
            ShimmerBox(width: 44, height: 10),
          ],
        ),
      ),
    );
  }
}
