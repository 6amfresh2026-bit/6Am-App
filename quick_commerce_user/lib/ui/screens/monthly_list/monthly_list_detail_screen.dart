import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_labels.dart';
import '../../../di/app_providers.dart';
import '../../../domain/model/monthly_list.dart';
import '../../../navigation/route_paths.dart';
import '../../common/widgets/buttons/primary_button.dart';
import '../../common/widgets/feedback/app_dialog.dart';
import '../../common/widgets/feedback/app_toast.dart';
import '../../common/widgets/inputs/app_text_field.dart';
import '../../common/widgets/loaders/full_page_loader.dart';
import '../../common/widgets/misc/quantity_stepper.dart';
import '../../common/widgets/states/error_state_widget.dart';
import 'monthly_list_detail_provider.dart';
import 'widgets/order_now_sheet.dart';

class MonthlyListDetailScreen extends ConsumerWidget {
  const MonthlyListDetailScreen({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = monthlyListDetailProvider(listId);
    final state = ref.watch(provider);
    final list = state.list;

    if (state.isLoading && list == null) {
      return const Scaffold(body: FullPageLoader());
    }
    if (list == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorStateWidget(
          failure: state.failure!,
          onRetry: () => ref.read(provider.notifier).load(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(list.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Rename',
            onPressed: () => _rename(context, ref, list),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      bottomNavigationBar: _OrderBar(listId: listId),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _SummaryCard(list: list),
            const SizedBox(height: AppSpacing.lg),
            Text('Items', style: context.text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            ...list.items.map(
              (item) => _ItemRow(
                item: item,
                enabled: !state.isBusy,
                onChanged: (quantity) =>
                    _setQuantity(context, ref, item, quantity),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _PauseTile(listId: listId, list: list),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Prices are not saved. Every order from this list is priced fresh '
              'at the current rates, and items that are out of stock are '
              'flagged before you pay.',
              style: context.text.bodySmall?.copyWith(
                color: context.semantic.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setQuantity(
    BuildContext context,
    WidgetRef ref,
    MonthlyListItem item,
    int quantity,
  ) async {
    final notifier = ref.read(monthlyListDetailProvider(listId).notifier);
    final ok = await notifier.setQuantity(item, quantity);
    if (ok || !context.mounted) return;
    AppToast.error(
      context,
      ref.read(monthlyListDetailProvider(listId)).failure?.message ??
          'Could not update that item.',
    );
    notifier.clearFailure();
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    MonthlyList list,
  ) async {
    final controller = TextEditingController(text: list.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename list'),
        content: AppTextField(
          controller: controller,
          label: 'List name',
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (name == null || name.isEmpty || !context.mounted) return;
    await ref.read(monthlyListDetailProvider(listId).notifier).rename(name);
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.list});

  final MonthlyList list;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.semantic.surfaceAlt,
        borderRadius: AppRadii.rLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (list.restaurantName.isNotEmpty) ...[
            Text(list.restaurantName, style: context.text.titleSmall),
            const SizedBox(height: AppSpacing.xxs),
          ],
          Text(
            '${list.itemCount} item${list.itemCount == 1 ? '' : 's'} · '
            '${list.totalQuantity} unit${list.totalQuantity == 1 ? '' : 's'}',
            style: context.text.bodyMedium,
          ),
          if (list.lastOrderedAt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Last ordered ${DateLabels.dayMonthYear(list.lastOrderedAt!)}',
              style: context.text.bodySmall?.copyWith(
                color: context.semantic.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.enabled,
    required this.onChanged,
  });

  final MonthlyListItem item;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.name.isEmpty ? 'Item' : item.name,
              style: context.text.bodyLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          QuantityStepper(
            quantity: item.quantity,
            // Stepping the last unit down removes the line, which the provider
            // refuses when it would empty the list — the message says so.
            onDecrement: enabled ? () => onChanged(item.quantity - 1) : () {},
            onIncrement: enabled ? () => onChanged(item.quantity + 1) : () {},
            canIncrement: enabled,
          ),
        ],
      ),
    );
  }
}

class _PauseTile extends ConsumerWidget {
  const _PauseTile({required this.listId, required this.list});

  final String listId;
  final MonthlyList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: list.isActive,
      title: Text('List is active', style: context.text.titleSmall),
      subtitle: Text(
        list.isActive
            ? 'You can order from this list.'
            : 'Paused — turn this on to order from it again.',
        style: context.text.bodySmall?.copyWith(
          color: context.semantic.textSecondary,
        ),
      ),
      onChanged: (value) =>
          ref.read(monthlyListDetailProvider(listId).notifier).setActive(value),
    );
  }
}

/// "Order this month" — collects the address and payment method, places the
/// order, then hands off to the same payment screen normal checkout uses.
class _OrderBar extends ConsumerWidget {
  const _OrderBar({required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(monthlyListDetailProvider(listId));
    final list = state.list;
    if (list == null) return const SizedBox.shrink();

    return SafeArea(
      minimum: const EdgeInsets.all(AppSpacing.lg),
      child: PrimaryButton(
        label: 'Order this month',
        icon: Icons.shopping_bag_outlined,
        isLoading: state.isOrdering,
        onPressed: list.canOrder ? () => _order(context, ref, list) : null,
      ),
    );
  }

  Future<void> _order(
    BuildContext context,
    WidgetRef ref,
    MonthlyList list,
  ) async {
    var address = ref.read(selectedAddressProvider);
    if (address == null) {
      final goPick = await AppDialog.confirm(
        context,
        title: 'Add a delivery address',
        message: 'Choose where this order should be delivered.',
        confirmLabel: 'Choose address',
        icon: Icons.location_on_outlined,
      );
      if (!goPick || !context.mounted) return;
      await context.push(RoutePaths.addresses);
      if (!context.mounted) return;
      address = ref.read(selectedAddressProvider);
      if (address == null) return;
    }

    final choice = await OrderNowSheet.show(context, address: address);
    if (choice == null || !context.mounted) return;

    final placed =
        await ref.read(monthlyListDetailProvider(listId).notifier).placeOrder(
              address: choice.address,
              method: choice.method,
            );

    if (!context.mounted) return;
    if (placed == null) {
      final failure = ref.read(monthlyListDetailProvider(listId)).failure;
      AppToast.error(context, failure?.message ?? 'Could not place that order.');
      ref.read(monthlyListDetailProvider(listId).notifier).clearFailure();
      return;
    }

    // Same handoff as checkout: the payment screen finishes cash orders and
    // opens the gateway for online ones.
    context.push(RoutePaths.payment, extra: placed);
  }
}
