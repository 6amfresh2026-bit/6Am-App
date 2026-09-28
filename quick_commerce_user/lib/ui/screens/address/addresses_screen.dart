import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../di/app_providers.dart';
import '../../../domain/model/address.dart';
import '../../../navigation/route_paths.dart';
import '../../common/widgets/buttons/primary_button.dart';
import '../../common/widgets/feedback/app_dialog.dart';
import '../../common/widgets/feedback/app_toast.dart';
import '../../common/widgets/loaders/list_skeleton.dart';
import '../../common/widgets/states/empty_state_widget.dart';
import '../../common/widgets/states/error_state_widget.dart';
import '../../common/widgets/misc/sound_refresh_indicator.dart';

/// Saved address management: pick, edit, delete, set default.
class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addressBookProvider);
    final controller = ref.read(addressBookProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Delivery addresses')),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md + MediaQuery.viewPaddingOf(context).bottom,
        ),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.semantic.border)),
        ),
        child: PrimaryButton(
          label: 'Add a new address',
          icon: Icons.add_location_alt_rounded,
          onPressed: () async {
            await context.push(RoutePaths.addressSelection);
            await controller.load();
          },
        ),
      ),
      body: SafeArea(
        child: switch (state) {
          _ when state.isLoading && state.addresses.isEmpty =>
            const ListSkeleton(count: 3, height: 108),
          _ when state.failure != null && state.addresses.isEmpty =>
            ErrorStateWidget(failure: state.failure!, onRetry: controller.load),
          _ when state.addresses.isEmpty => EmptyStateWidget(
              icon: Icons.location_off_outlined,
              title: 'No saved addresses',
              message:
                  'Add one so we know where to bring your order — it takes a moment.',
              actionLabel: 'Add address',
              onAction: () => context.push(RoutePaths.addressSelection),
            ),
          _ => SoundRefreshIndicator(
              onRefresh: controller.load,
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: state.addresses.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final address = state.addresses[index];
                  return _AddressTile(
                    address: address,
                    isSelected: state.selected?.id == address.id,
                    onSelect: () async {
                      await controller.select(address.id);
                      if (context.mounted) context.pop();
                    },
                    onEdit: () async {
                      await context.push(
                        RoutePaths.addressSelection,
                        extra: address,
                      );
                      await controller.load();
                    },
                    onDelete: () => _delete(context, ref, address),
                    onMakeDefault: () => controller.makeDefault(address.id),
                  );
                },
              ),
            ),
        },
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Address address,
  ) async {
    final confirmed = await AppDialog.confirm(
      context,
      icon: Icons.delete_outline_rounded,
      title: 'Delete this address?',
      message: address.fullLine,
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await ref.read(addressBookProvider.notifier).remove(address.id);
      if (context.mounted) AppToast.success(context, 'Address deleted');
    } catch (_) {
      if (context.mounted) {
        AppToast.error(context, 'Could not delete this address');
      }
    }
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.address,
    required this.isSelected,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onMakeDefault,
  });

  final Address address;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMakeDefault;

  IconData get _icon => switch (address.label) {
        AddressLabel.home => Icons.home_rounded,
        AddressLabel.office => Icons.business_rounded,
        AddressLabel.other => Icons.place_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(address.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        // Deletion is confirmed in a dialog, so never dismiss optimistically.
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        decoration: BoxDecoration(
          color: context.semantic.dangerSoft,
          borderRadius: AppRadii.rLg,
        ),
        child: Icon(Icons.delete_outline_rounded, color: context.semantic.danger),
      ),
      child: GestureDetector(
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: AppRadii.rLg,
            border: Border.all(
              color:
                  isSelected ? context.colors.primary : context.semantic.border,
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_icon, size: 17, color: context.colors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(address.label.wireValue, style: context.text.titleMedium),
                  if (address.isDefault) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: context.semantic.successSoft,
                        borderRadius: AppRadii.rSm,
                      ),
                      child: Text(
                        'DEFAULT',
                        style: context.text.labelSmall!
                            .copyWith(color: context.semantic.success),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (isSelected)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 19,
                      color: context.colors.primary,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(address.fullLine, style: context.text.bodyMedium),
              if (!address.hasCoordinates) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Not pinned on the map — delivery fees may be estimated',
                  style: context.text.bodySmall!
                      .copyWith(color: context.semantic.warning),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  TextButton(onPressed: onEdit, child: const Text('Edit')),
                  if (!address.isDefault)
                    TextButton(
                      onPressed: onMakeDefault,
                      child: const Text('Set as default'),
                    ),
                  const Spacer(),
                  IconButton(
                    onPressed: onDelete,
                    tooltip: 'Delete',
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 19,
                      color: context.semantic.danger,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
