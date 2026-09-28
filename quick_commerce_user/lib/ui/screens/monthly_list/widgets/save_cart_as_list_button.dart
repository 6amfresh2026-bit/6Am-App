import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../di/app_providers.dart';
import '../../../../domain/model/cart.dart';
import '../../../../domain/model/monthly_list.dart';
import '../../../../navigation/route_paths.dart';
import '../../../common/widgets/buttons/secondary_button.dart';
import '../../../common/widgets/feedback/app_toast.dart';
import '../../../common/widgets/inputs/app_text_field.dart';
import '../monthly_lists_provider.dart';

/// Turns the current cart into a reusable monthly list.
///
/// A list belongs to exactly one restaurant, which the cart already guarantees
/// — it holds items from a single seller at a time.
class SaveCartAsListButton extends ConsumerStatefulWidget {
  const SaveCartAsListButton({super.key, required this.cart});

  final Cart cart;

  @override
  ConsumerState<SaveCartAsListButton> createState() =>
      _SaveCartAsListButtonState();
}

class _SaveCartAsListButtonState extends ConsumerState<SaveCartAsListButton> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(authProvider).isSignedIn;
    if (!signedIn || widget.cart.items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: SecondaryButton(
        label: 'Save as monthly list',
        icon: Icons.playlist_add_rounded,
        expand: true,
        isLoading: _saving,
        onPressed: _saving ? null : _save,
      ),
    );
  }

  Future<void> _save() async {
    final name = await _askName();
    if (name == null || !mounted) return;

    setState(() => _saving = true);
    final items = widget.cart.items
        .map(
          (line) => MonthlyListItem(
            itemId: line.product.id,
            quantity: line.quantity,
            variantId: line.variant?.id ?? '',
            name: line.product.name,
          ),
        )
        .toList();

    final created = await ref.read(monthlyListsProvider.notifier).create(
          restaurantId: widget.cart.sellerId,
          items: items,
          name: name,
        );

    if (!mounted) return;
    setState(() => _saving = false);

    if (created == null) {
      AppToast.error(
        context,
        ref.read(monthlyListsProvider).failure?.message ??
            'Could not save that list.',
      );
      ref.read(monthlyListsProvider.notifier).clearFailure();
      return;
    }

    AppToast.success(
      context,
      'Saved as "${created.name}"',
      actionLabel: 'View',
      onAction: () =>
          context.push(RoutePaths.monthlyListDetailsOf(created.id)),
    );
  }

  Future<String?> _askName() async {
    final controller = TextEditingController(
      text: widget.cart.sellerName.isEmpty
          ? 'My Monthly List'
          : '${widget.cart.sellerName} monthly',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name this list'),
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
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    // An empty name is allowed — the backend falls back to "My Monthly List".
    return name;
  }
}
