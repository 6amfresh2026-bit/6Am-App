import 'package:flutter/material.dart';

import '../../../../../core/extensions/num_extensions.dart';
import '../../../../../core/utils/app_haptics.dart';
import '../../../../../core/theme/app_radii.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../domain/repository/product_repository.dart';
import '../../../../common/widgets/buttons/primary_button.dart';
import '../../../../common/widgets/buttons/secondary_button.dart';
import '../../../../common/widgets/feedback/app_bottom_sheet.dart';

/// Result handed back to the listing provider.
typedef SortFilterResult = ({ProductSort sort, ProductFilters filters});

/// Combined sort + filter sheet.
class SortFilterSheet extends StatefulWidget {
  const SortFilterSheet({
    super.key,
    required this.sort,
    required this.filters,
    required this.brands,
    required this.priceBounds,
  });

  final ProductSort sort;
  final ProductFilters filters;
  final List<String> brands;
  final ({double min, double max}) priceBounds;

  static Future<SortFilterResult?> show(
    BuildContext context, {
    required ProductSort sort,
    required ProductFilters filters,
    required List<String> brands,
    required ({double min, double max}) priceBounds,
  }) =>
      AppBottomSheet.show<SortFilterResult>(
        context,
        title: 'Sort & filter',
        subtitle: 'Narrow it down to exactly what you need',
        child: SortFilterSheet(
          sort: sort,
          filters: filters,
          brands: brands,
          priceBounds: priceBounds,
        ),
      );

  @override
  State<SortFilterSheet> createState() => _SortFilterSheetState();
}

class _SortFilterSheetState extends State<SortFilterSheet> {
  late ProductSort _sort = widget.sort;
  late ProductFilters _filters = widget.filters;
  late RangeValues _priceRange;

  static const _sortLabels = {
    ProductSort.relevance: 'Relevance',
    ProductSort.priceLowToHigh: 'Price: low to high',
    ProductSort.priceHighToLow: 'Price: high to low',
    ProductSort.rating: 'Customer rating',
    ProductSort.discount: 'Biggest discount',
  };

  double get _min => widget.priceBounds.min;
  double get _max =>
      widget.priceBounds.max > _min ? widget.priceBounds.max : _min + 100;

  @override
  void initState() {
    super.initState();
    _priceRange = RangeValues(
      (_filters.minPrice ?? _min).clamp(_min, _max),
      (_filters.maxPrice ?? _max).clamp(_min, _max),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            children: [
              _label(context, 'Sort by'),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _sortLabels.entries
                    .map(
                      (e) => _Chip(
                        label: e.value,
                        selected: _sort == e.key,
                        onTap: () => setState(() => _sort = e.key),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.xl),
              _label(context, 'Price range'),
              RangeSlider(
                values: _priceRange,
                min: _min,
                max: _max,
                divisions: 20,
                labels: RangeLabels(
                  _priceRange.start.asCurrency,
                  _priceRange.end.asCurrency,
                ),
                onChanged: (values) => setState(() => _priceRange = values),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_priceRange.start.asCurrency, style: context.text.titleSmall),
                  Text(_priceRange.end.asCurrency, style: context.text.titleSmall),
                ],
              ),
              if (widget.brands.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                _label(context, 'Brand'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: widget.brands
                      .map(
                        (brand) => _Chip(
                          label: brand,
                          selected: _filters.brand == brand,
                          onTap: () => setState(
                            () => _filters = _filters.brand == brand
                                ? _filters.copyWith(clearBrand: true)
                                : _filters.copyWith(brand: brand),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              _label(context, 'Discount'),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [10, 25, 40, 60]
                    .map(
                      (percent) => _Chip(
                        label: '$percent% and above',
                        selected: _filters.minDiscountPercent == percent,
                        onTap: () => setState(
                          () => _filters = _filters.minDiscountPercent == percent
                              ? _filters.copyWith(clearDiscount: true)
                              : _filters.copyWith(minDiscountPercent: percent),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _filters.vegOnly,
                title: Text('Vegetarian only', style: context.text.titleMedium),
                onChanged: (value) =>
                    setState(() => _filters = _filters.copyWith(vegOnly: value)),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _filters.inStockOnly,
                title: Text('In stock only', style: context.text.titleMedium),
                onChanged: (value) => setState(
                  () => _filters = _filters.copyWith(inStockOnly: value),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.lg + MediaQuery.viewPaddingOf(context).bottom,
          ),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: context.semantic.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Clear all',
                  expand: true,
                  onPressed: () => Navigator.of(context).pop((
                    sort: ProductSort.relevance,
                    filters: ProductFilters(categoryId: _filters.categoryId),
                  )),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: PrimaryButton(
                  label: 'Show results',
                  onPressed: () => Navigator.of(context).pop((
                    sort: _sort,
                    filters: _filters.copyWith(
                      minPrice: _priceRange.start > _min ? _priceRange.start : null,
                      maxPrice: _priceRange.end < _max ? _priceRange.end : null,
                      clearPrice:
                          _priceRange.start <= _min && _priceRange.end >= _max,
                    ),
                  )),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Text(text, style: context.text.titleLarge),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Every sort, brand and discount chip in the sheet routes through here,
      // so one selection cue covers all of them.
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: selected
              ? context.colors.primary.withValues(alpha: 0.10)
              : context.semantic.surfaceAlt,
          borderRadius: AppRadii.rPill,
          border: Border.all(
            color: selected ? context.colors.primary : context.semantic.border,
          ),
        ),
        child: Text(
          label,
          style: context.text.labelMedium!.copyWith(
            color: selected ? context.colors.primary : context.colors.onSurface,
          ),
        ),
      ),
    );
  }
}
