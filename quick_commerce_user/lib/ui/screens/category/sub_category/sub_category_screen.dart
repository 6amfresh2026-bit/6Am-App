import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../di/app_providers.dart';
import '../../../../domain/model/category.dart';
import '../../../../domain/model/product.dart';
import '../../../../domain/model/sub_category.dart';
import '../../../../navigation/route_paths.dart';
import '../../../common/cart_actions.dart';
import '../../../common/widgets/loaders/product_card_skeleton.dart';
import '../../../common/widgets/misc/app_network_image.dart';
import '../../../common/widgets/states/empty_state_widget.dart';
import '../../../common/widgets/states/error_state_widget.dart';
import '../../cart/widgets/cart_summary_bar.dart';
import '../../../common/widgets/buttons/secondary_button.dart';
import '../../../common/widgets/feedback/app_bottom_sheet.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_haptics.dart';
import 'sub_category_provider.dart';
import 'sub_category_state.dart';
import '../../../../core/theme/app_theme.dart';

class SubCategoryScreen extends ConsumerWidget {
  const SubCategoryScreen({super.key, required this.categoryId, this.category});

  final String categoryId;
  final Category? category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subCategoryProvider(categoryId));
    final title = category?.name ?? '';

    return Scaffold(
      backgroundColor: context.colors.surface,
      bottomNavigationBar: const CartSummaryBar(),
      body: SafeArea(
        child: Column(
          children: [
            // Top Quick-Commerce Header
            _buildHeader(context, title, ref.watch(selectedAddressProvider)?.shortLine),

            // Horizontal Filter & Sort Chips Row
            _buildFilterBar(context, ref, state),

            // Main Body: Subcategory Rail on left, Product Grid on right
            Expanded(
              child: switch (state) {
                _ when state.failure != null && state.allProducts.isEmpty =>
                  ErrorStateWidget(
                    failure: state.failure!,
                    onRetry: () =>
                        ref.read(subCategoryProvider(categoryId).notifier).load(),
                  ),
                _ when state.isLoading && state.allProducts.isEmpty =>
                  const _LoadingLayout(),
                _ when state.visibleProducts.isEmpty &&
                        state.hasActiveFilters =>
                  EmptyStateWidget(
                    icon: Icons.filter_alt_off_rounded,
                    title: 'No items match these filters',
                    message: 'Try widening the price range or clearing a filter.',
                    actionLabel: 'Clear filters',
                    onAction: () => ref
                        .read(subCategoryProvider(categoryId).notifier)
                        .clearFilters(),
                  ),
                _ when state.isEmpty => EmptyStateWidget(
                    icon: Icons.inventory_2_outlined,
                    title: 'Nothing here yet',
                    message:
                        'We are still stocking this category near you. Try another one.',
                    actionLabel: 'All categories',
                    onAction: () => context.go(RoutePaths.categories),
                  ),
                _ => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Rail (SubCategories)
                      _SubCategoryRail(
                        categoryId: categoryId,
                        selectedId: state.selectedId,
                        items: state.subCategories,
                      ),

                      // Right Product Grid (2 Columns)
                      Expanded(
                        child: Container(
                          color: context.semantic.surfaceAlt,
                          child: GridView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: state.visibleProducts.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 0.52,
                            ),
                            itemBuilder: (context, index) {
                              final product = state.visibleProducts[index];
                              return _BrowseProductCard(
                                product: product,
                                heroTag: 'sub-$categoryId',
                                onTap: () => context.push(
                                  RoutePaths.productDetailsOf(product.id),
                                  extra: product,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String categoryTitle,
    String? deliveryAddress,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(bottom: BorderSide(color: context.semantic.border, width: 1)),
      ),
      child: Row(
        children: [
          // Back Button Circle
          InkWell(
            onTap: () => context.pop(),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: context.semantic.border),
              ),
              child: Icon(Icons.arrow_back, size: 20, color: context.colors.onSurface),
            ),
          ),
          const SizedBox(width: 10),
          // Title & Delivery location
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  categoryTitle,
                  style: context.text.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: context.colors.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      "Delivering to : ",
                      style: context.text.bodySmall!.copyWith(fontWeight: FontWeight.w700, color: context.semantic.success),
                    ),
                    Flexible(
                      child: Text(
                        deliveryAddress ?? 'Select an address',
                        style: context.text.bodySmall!.copyWith(fontWeight: FontWeight.w500, color: context.semantic.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, size: 16, color: context.semantic.textSecondary),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Search Circle Button
          InkWell(
            onTap: () => context.push(RoutePaths.search),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: context.semantic.border),
              ),
              child: Icon(Icons.search_rounded, size: 20, color: context.colors.onSurface),
            ),
          ),
          // Category sharing is deliberately absent: the backend renders share
          // pages for products and sellers only (shareLinks.routes.js), and the
          // `suvio://category/<id>` link this button used to send resolves
          // nowhere — no scheme is registered and there is no web page behind
          // it. Restore once a category share page exists (BACKEND REQUIRED).
        ],
      ),
    );
  }

  /// The chip row. Every chip opens the filter sheet focused on its own
  /// section; "Filters" opens all of them. Selections are reflected in the chip
  /// itself so the row doubles as the active-filter summary.
  Widget _buildFilterBar(BuildContext context, WidgetRef ref, SubCategoryState state) {
    final controller = ref.read(subCategoryProvider(categoryId).notifier);

    final chips = <_FilterChipSpec>[
      _FilterChipSpec(
        label: state.activeFilterCount == 0
            ? 'Filters'
            : 'Filters (${state.activeFilterCount})',
        icon: Icons.tune_rounded,
        active: state.activeFilterCount > 0,
        section: _FilterSection.all,
      ),
      _FilterChipSpec(
        label: state.sort == ProductSort.relevance ? 'Sort' : state.sort.label,
        icon: Icons.swap_vert_rounded,
        active: state.sort != ProductSort.relevance,
        section: _FilterSection.sort,
      ),
      _FilterChipSpec(
        label: state.diet == DietFilter.any ? 'Diet Preference' : state.diet.label,
        active: state.diet != DietFilter.any,
        section: _FilterSection.diet,
      ),
      _FilterChipSpec(
        label: state.brand.isEmpty ? 'Brand' : state.brand,
        active: state.brand.isNotEmpty,
        section: _FilterSection.brand,
      ),
      _FilterChipSpec(
        label: state.priceBand == PriceBand.any ? 'Price' : state.priceBand.label,
        active: state.priceBand != PriceBand.any,
        section: _FilterSection.price,
      ),
    ];

    return Container(
      height: 44,
      color: context.colors.surface,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = chips[index];
          return InkWell(
            onTap: () => _openFilterSheet(context, ref, controller, chip.section),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: chip.active
                    ? context.colors.primary.withValues(alpha: 0.16)
                    : context.colors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: chip.active
                      ? context.colors.primary
                      : context.semantic.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (chip.icon != null) ...[
                    Icon(chip.icon, size: 14, color: context.colors.onSurface),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    chip.label,
                    style: context.text.labelMedium!.copyWith(
                      color: context.colors.onSurface,
                      fontWeight: chip.active ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: context.semantic.textSecondary,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openFilterSheet(
    BuildContext context,
    WidgetRef ref,
    SubCategoryController controller,
    _FilterSection section,
  ) =>
      AppBottomSheet.show<void>(
        context,
        title: switch (section) {
          _FilterSection.all => 'Filters',
          _FilterSection.sort => 'Sort by',
          _FilterSection.diet => 'Diet preference',
          _FilterSection.brand => 'Brand',
          _FilterSection.price => 'Price',
        },
        child: _FilterSheet(
          categoryId: categoryId,
          section: section,
          controller: controller,
        ),
      );
}

enum _FilterSection { all, sort, diet, brand, price }

class _FilterChipSpec {
  const _FilterChipSpec({
    required this.label,
    required this.section,
    this.icon,
    this.active = false,
  });

  final String label;
  final _FilterSection section;
  final IconData? icon;
  final bool active;
}

/// Filter and sort controls. Reads live state so the sheet updates as options
/// are picked, and applies each change immediately — no "Apply" button to miss.
class _FilterSheet extends ConsumerWidget {
  const _FilterSheet({
    required this.categoryId,
    required this.section,
    required this.controller,
  });

  final String categoryId;
  final _FilterSection section;
  final SubCategoryController controller;

  bool _shows(_FilterSection s) =>
      section == _FilterSection.all || section == s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subCategoryProvider(categoryId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_shows(_FilterSection.sort)) ...[
          const _GroupLabel('Sort by'),
          for (final option in ProductSort.values)
            _OptionRow(
              label: option.label,
              selected: state.sort == option,
              onTap: () => controller.setSort(option),
            ),
        ],
        if (_shows(_FilterSection.diet)) ...[
          const _GroupLabel('Diet preference'),
          for (final option in DietFilter.values)
            _OptionRow(
              label: option.label,
              selected: state.diet == option,
              onTap: () => controller.setDiet(option),
            ),
        ],
        if (_shows(_FilterSection.brand)) ...[
          const _GroupLabel('Brand'),
          if (state.brands.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                'The items here do not carry a brand.',
                style: context.text.bodyMedium!
                    .copyWith(color: context.semantic.textSecondary),
              ),
            )
          else ...[
            _OptionRow(
              label: 'All brands',
              selected: state.brand.isEmpty,
              onTap: () => controller.setBrand(''),
            ),
            for (final brand in state.brands)
              _OptionRow(
                label: brand,
                selected: state.brand == brand,
                onTap: () => controller.setBrand(brand),
              ),
          ],
        ],
        if (_shows(_FilterSection.price)) ...[
          const _GroupLabel('Price'),
          for (final band in PriceBand.values)
            _OptionRow(
              label: band.label,
              selected: state.priceBand == band,
              onTap: () => controller.setPriceBand(band),
            ),
        ],
        if (state.hasActiveFilters) ...[
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            label: 'Clear all filters',
            expand: true,
            icon: Icons.filter_alt_off_rounded,
            onPressed: () {
              controller.clearFilters();
              Navigator.of(context).pop();
            },
          ),
        ],
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.md,
          bottom: AppSpacing.xs,
        ),
        child: Text(text, style: context.text.titleSmall),
      );
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.rMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: context.text.bodyLarge!.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected
                  ? context.colors.primary
                  : context.semantic.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SubCategoryRail extends ConsumerWidget {
  const _SubCategoryRail({
    required this.categoryId,
    required this.selectedId,
    required this.items,
  });

  final String categoryId;
  final String selectedId;
  final List<SubCategory> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 78,
      color: context.semantic.surfaceAlt,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 20),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final sub = items[index];
          final selected = sub.id == selectedId || (selectedId == 'all' && index == 0);

          return GestureDetector(
            onTap: () =>
                ref.read(subCategoryProvider(categoryId).notifier).select(sub.id),
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(
                    color: selected ? context.colors.surface : Colors.transparent,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.colors.surface,
                          border: Border.all(
                            color: selected ? context.semantic.success : context.semantic.surfaceAlt,
                            width: selected ? 1.5 : 1,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: context.semantic.success.withValues(alpha: 0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: AppNetworkImage(
                            url: sub.imageUrl,
                            fit: BoxFit.cover,
                            fallbackIcon: Icons.grid_view_rounded,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          sub.name,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelSmall!.copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? context.colors.onSurface : context.semantic.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                // Green indicator bar on the right side when selected
                if (selected)
                  Positioned(
                    top: 10,
                    bottom: 10,
                    right: 0,
                    width: 3.5,
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.semantic.success,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          bottomLeft: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BrowseProductCard extends ConsumerStatefulWidget {
  const _BrowseProductCard({
    required this.product,
    required this.onTap,
    this.heroTag,
  });

  final Product product;
  final VoidCallback onTap;
  final String? heroTag;

  @override
  ConsumerState<_BrowseProductCard> createState() => _BrowseProductCardState();
}

class _BrowseProductCardState extends ConsumerState<_BrowseProductCard> {
  final _imageKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final quantity = ref.watch(cartProvider.select((s) => s.cart.quantityOf(product.id)));
    final isWishlisted = ref.watch(isWishlistedProvider(product.id));

    final hasDiscount = product.strikePrice != null && product.strikePrice! > product.price;
    final optionsText = product.hasVariants
        ? '${product.variants.length} options'
        : (product.unitLabel.contains('options') ? product.unitLabel : null);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.semantic.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image Stack Container
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 125,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: context.semantic.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AppNetworkImage(
                      key: _imageKey,
                      url: product.imageUrl,
                      fit: BoxFit.contain,
                      fallbackIcon: Icons.fastfood_rounded,
                    ),
                  ),
                ),
                // Wishlist Heart (Top Right)
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => CartActions.toggleWishlist(context, ref, product),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 15,
                        color: isWishlisted ? context.semantic.danger : context.semantic.textSecondary,
                      ),
                    ),
                  ),
                ),
                // Ad Badge & Carousel Dots (Bottom Left)
                Positioned(
                  left: 4,
                  bottom: 6,
                  child: Row(
                    children: [
                      // Carousel Dots Indicator
                      Row(
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: context.colors.surface,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 2.5),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 2.5),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Green Veg Icon (Bottom Right of Image)
                Positioned(
                  right: 4,
                  bottom: 6,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      border: Border.all(color: context.semantic.success, width: 1.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Center(
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: context.semantic.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
                // ADD Button Overlay (Positioned at bottom-right of image)
                Positioned(
                  right: 2,
                  bottom: -10,
                  child: _buildAddButton(context, quantity, product, optionsText),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Unit / Weight
            Text(
              product.unitLabel,
              style: context.text.bodySmall!.copyWith(fontWeight: FontWeight.w500, color: context.semantic.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 3),

            // Price Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '₹${product.price.toInt()}',
                  style: context.text.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: context.colors.onSurface),
                ),
                if (hasDiscount) ...[
                  const SizedBox(width: 4),
                  Text(
                    '₹${product.strikePrice!.toInt()}',
                    style: context.text.bodySmall!.copyWith(fontWeight: FontWeight.w500, color: context.semantic.textSecondary, decoration: TextDecoration.lineThrough),
                  ),
                ],
              ],
            ),

            // Discount Badge (e.g., "5% OFF on MRP")
            if (product.discountPercent > 0)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  '${product.discountPercent}% OFF on MRP',
                  style: context.text.labelSmall!.copyWith(fontWeight: FontWeight.w700, color: context.colors.tertiary),
                ),
              ),

            const SizedBox(height: 3),

            // Product Name
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall!.copyWith(fontWeight: FontWeight.w600, color: context.colors.onSurface),
            ),

            const SizedBox(height: 4),

            // Ratings & Order Count — only once the catalog has ratings for it.
            if (product.ratingCount > 0) ...[
              Row(
                children: [
                  for (var i = 1; i <= 5; i++) ...[
                    Icon(
                      product.rating >= i
                          ? Icons.star_rounded
                          : product.rating >= i - 0.5
                              ? Icons.star_half_rounded
                              : Icons.star_outline_rounded,
                      size: 13,
                      color: context.semantic.warning,
                    ),
                    const SizedBox(width: 2),
                  ],
                  const SizedBox(width: 2),
                  Text(
                    _formatRatingCount(product.ratingCount),
                    style: context.text.labelSmall!.copyWith(fontWeight: FontWeight.w500, color: context.semantic.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 3),
            ],

            // Delivery Time Row — hidden when the seller has no promise set.
            if (product.deliveryMinutes != null)
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 12, color: context.semantic.textSecondary),
                const SizedBox(width: 3),
                Text(
                  '${product.deliveryMinutes} mins',
                  style: context.text.labelSmall!.copyWith(fontWeight: FontWeight.w600, color: context.semantic.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatRatingCount(int count) {
    if (count >= 100000) {
      return '${(count / 100000).toStringAsFixed(1)} lac';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return '$count';
  }

  Widget _buildAddButton(
    BuildContext context,
    int quantity,
    Product product,
    String? optionsText,
  ) {
    if (quantity == 0) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            AppHaptics.medium();
            CartActions.add(
              context,
              ref,
              product: product,
              sourceKey: _imageKey,
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 66,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.semantic.success, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ADD',
                  style: context.text.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: context.semantic.success),
                ),
                if (optionsText != null)
                  Text(
                    optionsText,
                    style: context.text.labelSmall!.copyWith(fontWeight: FontWeight.w500, color: context.semantic.success),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: 66,
      height: 32,
      decoration: BoxDecoration(
        color: context.semantic.success,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: context.semantic.success.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          GestureDetector(
            onTap: () => CartActions.decrement(ref, product),
            child: Icon(Icons.remove, size: 14, color: context.colors.surface),
          ),
          Text(
            '$quantity',
            style: context.text.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: context.colors.surface),
          ),
          GestureDetector(
            onTap: () => CartActions.increment(ref, product),
            child: Icon(Icons.add, size: 14, color: context.colors.surface),
          ),
        ],
      ),
    );
  }
}

class _LoadingLayout extends StatelessWidget {
  const _LoadingLayout();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 78, color: context.semantic.surfaceAlt),
        const Expanded(child: ProductGridSkeleton(count: 6)),
      ],
    );
  }
}

