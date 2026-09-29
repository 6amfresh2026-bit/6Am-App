import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

/// Gates whether a signed-in customer still needs to be asked for a delivery
/// address, and remembers that they were asked.
///
/// Kept apart from the screen itself so every entry point that can land a
/// customer on Home — OTP verification, finishing registration, and a cold
/// start that restores an existing session — asks the same question the same
/// way, before Home is ever shown.
abstract final class LocationOnboarding {
  /// True once, per customer: the first time they are signed in with no
  /// saved address. Marks them as asked immediately, so a crash or a
  /// force-quit on the next screen can never turn this into a loop, and so a
  /// customer who chooses "I'll do this later" is not nagged again on their
  /// next app open — checkout still asks for an address when one is needed.
  static Future<bool> needsCapture(WidgetRef ref) async {
    final user = ref.read(authProvider).user;
    if (user == null || user.id.isEmpty) return false;

    final storage = ref.read(localStorageProvider);
    final prompted = storage.getStringList(StorageKeys.locationPromptedUserIds);
    if (prompted.contains(user.id)) return false;

    // Trust the loaded address book; refresh it first if it has not run yet
    // so a returning customer is never asked for an address they already have.
    var book = ref.read(addressBookProvider);
    if (book.addresses.isEmpty && book.isLoading) {
      await ref.read(addressBookProvider.notifier).load();
      book = ref.read(addressBookProvider);
    }
    if (book.addresses.isNotEmpty) return false;

    await storage.setStringList(
      StorageKeys.locationPromptedUserIds,
      [...prompted, user.id],
    );
    return true;
  }
}

/// Full-screen "where should we deliver?" step shown right after sign-in,
/// before Home — not a dismissible overlay on top of it. Reuses the same
/// current-location + address-form flow as the address book's "add address".
class LocationOnboardingScreen extends ConsumerStatefulWidget {
  const LocationOnboardingScreen({super.key});

  @override
  ConsumerState<LocationOnboardingScreen> createState() =>
      _LocationOnboardingScreenState();
}

class _LocationOnboardingScreenState
    extends ConsumerState<LocationOnboardingScreen> {
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

  Future<void> _openAddressForm({Object? extra}) async {
    final saved =
        await context.push<bool>(RoutePaths.addressSelection, extra: extra);
    if (!mounted) return;
    if (saved == true) _goHome();
  }

  void _goHome() => context.go(RoutePaths.home);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  size: 48,
                  color: context.colors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Where should we deliver?',
                textAlign: TextAlign.center,
                style: context.text.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Sharing your location lets us show what is in stock near you '
                'and give you an honest delivery time.',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(
                  color: context.semantic.textSecondary,
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Allow location access',
                icon: Icons.my_location_rounded,
                isLoading: _locating,
                expand: true,
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
                onPressed: _locating ? null : _goHome,
                child: Text(
                  'I will do this later',
                  style: context.text.labelLarge?.copyWith(
                    color: context.semantic.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
