import 'package:flutter/material.dart';

import '../../../../core/extensions/num_extensions.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/model/addon.dart';
import '../../../common/widgets/badges/delivery_time_badge.dart';
import '../../../common/widgets/buttons/primary_button.dart';
import '../../../common/widgets/feedback/app_bottom_sheet.dart';

/// Multi-select add-on chooser with a live running subtotal.
///
/// Group rules (`minSelect`/`maxSelect`) come from the backend and are enforced
/// here: a single-select group behaves like a radio list, and the confirm
/// button stays disabled until every required group is satisfied.
class AddonSheet extends StatefulWidget {
  const AddonSheet({
    super.key,
    required this.groups,
    required this.basePrice,
    this.initial = const [],
  });

  final List<AddonGroup> groups;
  final double basePrice;
  final List<Addon> initial;

  static Future<List<Addon>?> show(
    BuildContext context, {
    required List<AddonGroup> groups,
    required String productName,
    required double basePrice,
    List<Addon> initial = const [],
  }) =>
      AppBottomSheet.show<List<Addon>>(
        context,
        title: 'Customise $productName',
        subtitle: 'Add extras to your order',
        child: AddonSheet(
          groups: groups,
          basePrice: basePrice,
          initial: initial,
        ),
      );

  @override
  State<AddonSheet> createState() => _AddonSheetState();
}

class _AddonSheetState extends State<AddonSheet> {
  late final Set<String> _selectedIds = widget.initial.map((a) => a.id).toSet();

  List<Addon> get _selected => widget.groups
      .expand((g) => g.options)
      .where((a) => _selectedIds.contains(a.id))
      .toList();

  double get _runningTotal =>
      widget.basePrice + _selected.fold<double>(0, (sum, a) => sum + a.price);

  /// Every group whose minimum selection is not yet met.
  List<AddonGroup> get _unsatisfied => widget.groups
      .where((g) =>
          g.isRequired &&
          g.options.where((o) => _selectedIds.contains(o.id)).length < g.minSelect)
      .toList();

  void _toggle(AddonGroup group, Addon addon) {
    setState(() {
      if (_selectedIds.contains(addon.id)) {
        _selectedIds.remove(addon.id);
        return;
      }

      if (group.isSingleSelect) {
        for (final option in group.options) {
          _selectedIds.remove(option.id);
        }
      } else if (group.hasLimit) {
        final chosen =
            group.options.where((o) => _selectedIds.contains(o.id)).length;
        if (chosen >= group.maxSelect) return;
      }
      _selectedIds.add(addon.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _unsatisfied.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            itemCount: widget.groups.length,
            itemBuilder: (context, index) {
              final group = widget.groups[index];
              return _AddonGroupSection(
                group: group,
                selectedIds: _selectedIds,
                onToggle: (addon) => _toggle(group, addon),
              );
            },
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg + MediaQuery.viewPaddingOf(context).bottom,
          ),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: context.semantic.border)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selected.isEmpty
                        ? 'No extras added'
                        : '${_selected.length} extra${_selected.length == 1 ? '' : 's'} added',
                    style: context.text.bodyMedium,
                  ),
                  Text(_runningTotal.asCurrency, style: context.text.priceLarge),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: blocked
                    ? 'Choose from ${_unsatisfied.first.name}'
                    : 'Add to cart',
                onPressed:
                    blocked ? null : () => Navigator.of(context).pop(_selected),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddonGroupSection extends StatelessWidget {
  const _AddonGroupSection({
    required this.group,
    required this.selectedIds,
    required this.onToggle,
  });

  final AddonGroup group;
  final Set<String> selectedIds;
  final ValueChanged<Addon> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Text(
                group.name.isEmpty ? 'Extras' : group.name,
                style: context.text.titleLarge,
              ),
            ),
            if (group.isRequired)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: context.semantic.warningSoft,
                  borderRadius: AppRadii.rSm,
                ),
                child: Text(
                  'Required',
                  style: context.text.badgeLabel
                      .copyWith(color: context.semantic.warning),
                ),
              ),
          ],
        ),
        if (group.selectionLabel.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(group.selectionLabel, style: context.text.bodySmall),
        ],
        const SizedBox(height: AppSpacing.sm),
        ...group.options.map(
          (addon) => _AddonTile(
            addon: addon,
            selected: selectedIds.contains(addon.id),
            isSingleSelect: group.isSingleSelect,
            onTap: () => onToggle(addon),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

class _AddonTile extends StatelessWidget {
  const _AddonTile({
    required this.addon,
    required this.selected,
    required this.isSingleSelect,
    required this.onTap,
  });

  final Addon addon;
  final bool selected;
  final bool isSingleSelect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.rSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            VegIndicator(isVeg: addon.isVeg),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(addon.name, style: context.text.bodyLarge),
                  if (addon.description.isNotEmpty)
                    Text(
                      addon.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall,
                    ),
                ],
              ),
            ),
            Text('+ ${addon.price.asCurrency}', style: context.text.titleSmall),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              isSingleSelect
                  ? (selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded)
                  : (selected
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded),
              size: 20,
              color: selected ? context.colors.primary : context.semantic.border,
            ),
          ],
        ),
      ),
    );
  }
}
