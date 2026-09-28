import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/local_storage/local_storage.dart';
import '../../../../di/app_providers.dart';
import '../../../../di/repository_providers.dart';
import '../../../../navigation/route_paths.dart';
import '../../../../platform/location/location_service.dart';
import '../../../common/widgets/buttons/primary_button.dart';
import '../../../common/widgets/buttons/secondary_button.dart';
import '../../../common/widgets/feedback/app_toast.dart';
import '../../home/home_provider.dart';

/// Asks a freshly signed-in customer where to deliver.
///
/// Shown as a popup over Home rather than as a screen in the sign-in stack, so
/// the customer can see the app behind it and the address is always collected
/// **after** authentication — saving one is an authenticated call, and asking
/// any earlier is what produced "unauthorized" on the very first save.
abstract final class LocationPromptSheet {
  /// Shows the prompt once per customer: on their first sign-in, when they
  /// have no saved address yet.
  ///
  /// Deliberately **not** repeated on later app opens. Someone who dismissed it
  /// has said no, and asking again every time they open the app is nagging —
  /// they can still add an address from their account, and checkout asks for
  /// one anyway. The "asked" mark is recorded the moment it is shown, whether
  /// or not they go on to add one.
  static Future<void> showIfNeeded(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authProvider).user;
    if (user == null || user.id.isEmpty) return;

    final storage = ref.read(localStorageProvider);
    final prompted = storage.getStringList(StorageKeys.locationPromptedUserIds);

    // Cheap check first, before any network: if this customer has already been
    // asked there is nothing to do, whatever their address book says.
    if (!shouldPrompt(
      userId: user.id,
      alreadyPrompted: prompted,
      hasSavedAddress: false,
    )) {
      return;
    }

    // Trust the loaded address book; refresh it first if it has not run yet so
    // a returning customer is never asked for an address they already have.
    final book = ref.read(addressBookProvider);
    if (book.addresses.isEmpty && book.isLoading) {
      await ref.read(addressBookProvider.notifier).load();
    }
    if (!context.mounted) return;

    if (!shouldPrompt(
      userId: user.id,
      alreadyPrompted: prompted,
      hasSavedAddress: ref.read(addressBookProvider).addresses.isNotEmpty,
    )) {
      return;
    }

    // Recorded before showing, so a crash or a force-quit mid-sheet cannot
    // turn this back into a prompt that reappears forever.
    await storage.setStringList(
      StorageKeys.locationPromptedUserIds,
      [...prompted, user.id],
    );

    if (!context.mounted) return;
    await show(context);
  }

  /// The rule, in one place: ask a signed-in customer who has not been asked
  /// before and has no address saved yet.
  @visibleForTesting
  static bool shouldPrompt({
    required String userId,
    required List<String> alreadyPrompted,
    required bool hasSavedAddress,
  }) =>
      userId.isNotEmpty &&
      !alreadyPrompted.contains(userId) &&
      !hasSavedAddress;

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        // Dismissible on purpose: a customer who wants to browse first can,
        // and checkout still blocks without an address.
        builder: (context) => const _LocationPromptBody(),
      );
}

class _LocationPromptBody extends ConsumerStatefulWidget {
  const _LocationPromptBody();

  @override
  ConsumerState<_LocationPromptBody> createState() => _LocationPromptBodyState();
}

class _LocationPromptBodyState extends ConsumerState<_LocationPromptBody> {
  bool _locating = false;

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final location = await ref.read(locationServiceProvider).currentLocation();
      if (!mounted) return;
      await _openAddressForm(extra: location);
    } on LocationPermissionDenied {
      if (!mounted) return;
      AppToast.error(
        context,
        'Location access is off. You can still enter your address manually.',
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Opens the shared address form. It reports `true` only once the backend has
  /// actually stored the address, which is when Home is worth rebuilding.
  Future<void> _openAddressForm({Object? extra}) async {
    final saved =
        await context.push<bool>(RoutePaths.addressSelection, extra: extra);
    if (!mounted) return;

    if (saved == true) {
      ref.invalidate(homeProvider);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadii.sheetTop,
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.semantic.border,
              borderRadius: AppRadii.rPill,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_on_rounded,
              size: 32,
              color: context.colors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Where should we deliver?',
            textAlign: TextAlign.center,
            style: context.text.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Sharing your location lets us show what is in stock near you and '
            'give you an honest delivery time.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: context.semantic.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: 'Allow location access',
            icon: Icons.my_location_rounded,
            isLoading: _locating,
            onPressed: _locating ? null : _useCurrentLocation,
          ),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            label: 'Enter address manually',
            icon: Icons.edit_location_alt_outlined,
            expand: true,
            onPressed: _locating ? null : () => _openAddressForm(),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'I will do this later',
              style: context.text.labelLarge?.copyWith(
                color: context.semantic.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
