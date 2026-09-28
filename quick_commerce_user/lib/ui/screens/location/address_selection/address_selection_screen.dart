import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/logger.dart';
import '../../../../di/app_providers.dart';
import '../../../../di/repository_providers.dart';
import '../../../../domain/model/address.dart';
import '../../../../domain/model/place.dart';
import '../../../../domain/validator/address_validator.dart';
import '../../../../navigation/route_paths.dart';
import '../../../../platform/location/location_service.dart';
import '../../../common/widgets/buttons/primary_button.dart';
import '../../../common/widgets/buttons/secondary_button.dart';
import '../../../common/widgets/feedback/app_toast.dart';
import '../../../common/widgets/inputs/app_text_field.dart';
import '../../../common/widgets/maps/address_picker_map.dart';
import 'widgets/place_search_field.dart';

/// Add or edit a delivery address.
///
/// Used by onboarding, the address book and checkout's "Change" action.
class AddressSelectionScreen extends ConsumerStatefulWidget {
  const AddressSelectionScreen({super.key, this.existing, this.initialLocation});

  /// Non-null when editing.
  final Address? existing;

  /// Pre-filled coordinates when arriving from "use my location".
  final DeviceLocation? initialLocation;

  @override
  ConsumerState<AddressSelectionScreen> createState() =>
      _AddressSelectionScreenState();
}

class _AddressSelectionScreenState
    extends ConsumerState<AddressSelectionScreen> {
  static const _validator = AddressValidator();

  late final TextEditingController _street;
  late final TextEditingController _details;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _zip;
  late final TextEditingController _phone;
  late final TextEditingController _flat;
  late final TextEditingController _block;
  late final TextEditingController _colony;

  late AddressLabel _label;
  double? _latitude;
  double? _longitude;
  Map<String, String> _errors = const {};
  bool _saving = false;
  bool _locating = false;
  bool _resolvingPin = false;
  String _pinAddress = '';

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final location = widget.initialLocation;

    _street = TextEditingController(text: existing?.street ?? '');
    _details = TextEditingController(text: existing?.additionalDetails ?? '');
    _city = TextEditingController(text: existing?.city ?? location?.city ?? '');
    _state =
        TextEditingController(text: existing?.state ?? location?.state ?? '');
    _zip =
        TextEditingController(text: existing?.zipCode ?? location?.pincode ?? '');
    _phone = TextEditingController(text: existing?.phone ?? '');
    _flat = TextEditingController(text: existing?.flatNumber ?? '');
    _block = TextEditingController(text: existing?.blockNumber ?? '');
    _colony = TextEditingController(text: existing?.colonyName ?? '');
    _label = existing?.label ?? AddressLabel.home;
    _latitude = existing?.latitude ?? location?.latitude;
    _longitude = existing?.longitude ?? location?.longitude;
  }

  @override
  void dispose() {
    _street.dispose();
    _details.dispose();
    _city.dispose();
    _state.dispose();
    _zip.dispose();
    _phone.dispose();
    _flat.dispose();
    _block.dispose();
    _colony.dispose();
    super.dispose();
  }

  Address get _address => Address(
        id: widget.existing?.id ?? '',
        label: _label,
        street: _street.text.trim(),
        city: _city.text.trim(),
        state: _state.text.trim(),
        additionalDetails: _details.text.trim(),
        zipCode: _zip.text.trim(),
        phone: _phone.text.trim(),
        flatNumber: _flat.text.trim(),
        blockNumber: _block.text.trim(),
        colonyName: _colony.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        isDefault: widget.existing?.isDefault ?? false,
      );

  /// Explicit user action: take the GPS fix as the truth and refill the form
  /// from it, overwriting anything a previous tap left behind. Fields Google
  /// has nothing for are cleared rather than left stale, so what is on screen
  /// always describes the pin — the user types the rest.
  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final location = await ref.read(locationServiceProvider).currentLocation();
      if (!mounted) return;

      setState(() {
        _latitude = location.latitude;
        _longitude = location.longitude;
        _pinAddress = location.formattedAddress;
        _street.text = location.streetLine;
        _details.text =
            location.subLocality.isNotEmpty ? location.subLocality : location.label;
        _city.text = location.city;
        _state.text = location.state;
        _zip.text = location.pincode;
        _errors = {..._errors}..remove('location');
      });

      if (!location.isResolved) {
        // Two different causes, two different fixes — say which one it is
        // rather than making the user guess.
        AppToast.error(
          context,
          ref.read(appConfigProvider).hasMapsKey
              ? 'We placed the pin but could not read the address. Please fill it in.'
              : 'Address lookup is not configured in this build (MAPS_API_KEY). '
                  'Please enter the address manually.',
        );
      } else if (_street.text.trim().isEmpty) {
        AppToast.show(context, 'Add your house / flat number to finish');
      }
    } on LocationPermissionDenied catch (e) {
      if (!mounted) return;
      if (e.isPermanent) {
        AppToast.show(
          context,
          'Location is turned off for Suvio Quick. Enable it in Settings.',
          actionLabel: 'SETTINGS',
          onAction: () => ref.read(permissionServiceProvider).openSettings(),
        );
      } else {
        AppToast.error(
          context,
          'Location access was denied — allow it or enter the address manually.',
        );
      }
    } on LocationUnavailable catch (e) {
      // GPS switched off, no fix within the timeout, or no last-known position.
      if (mounted) AppToast.error(context, e.message);
    } catch (e) {
      AppLogger.error('current location failed', error: e);
      if (mounted) {
        AppToast.error(context, 'Could not get your location. Try again.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Fires when the map camera settles on a new centre.
  Future<void> _onCentreChanged(double latitude, double longitude) async {
    // Ignore sub-metre jitter so an idle map does not bill geocoding calls.
    // This also absorbs the idle event from a programmatic recentre — the
    // camera lands on coordinates we just set, so there is nothing to resolve.
    if (_latitude != null &&
        _longitude != null &&
        (_latitude! - latitude).abs() < 0.00002 &&
        (_longitude! - longitude).abs() < 0.00002) {
      return;
    }

    setState(() {
      _latitude = latitude;
      _longitude = longitude;
      _resolvingPin = true;
      _errors = {..._errors}..remove('location');
    });

    final location =
        await ref.read(locationServiceProvider).resolve(latitude, longitude);
    if (!mounted) return;

    setState(() {
      _resolvingPin = false;
      _pinAddress = location.formattedAddress;
      // Only fill blanks — never overwrite what the user has typed.
      if (_city.text.trim().isEmpty) _city.text = location.city;
      if (_state.text.trim().isEmpty) _state.text = location.state;
      if (_zip.text.trim().isEmpty) _zip.text = location.pincode;
    });
  }

  /// Fires when a Places suggestion is chosen.
  void _onPlaceSelected(ResolvedPlace place) {
    setState(() {
      _latitude = place.latitude;
      _longitude = place.longitude;
      _pinAddress = place.formattedAddress;
      // Only fill blanks — never overwrite what the user has typed.
      if (_street.text.trim().isEmpty && place.streetLine.isNotEmpty) {
        _street.text = place.streetLine;
      }
      if (_details.text.trim().isEmpty) _details.text = place.subLocality;
      _city.text = place.city;
      _state.text = place.state;
      if (place.postalCode.isNotEmpty) _zip.text = place.postalCode;
      _errors = {..._errors}..remove('location');
    });
  }

  Future<void> _save() async {
    final errors = _validator.validate(_address);
    setState(() => _errors = errors);
    if (errors.isNotEmpty) {
      AppToast.error(context, errors.values.first);
      return;
    }

    setState(() => _saving = true);
    try {
      final controller = ref.read(addressBookProvider.notifier);
      if (widget.existing == null) {
        await controller.add(_address);
      } else {
        await controller.update(_address);
      }
      if (!mounted) return;

      AppToast.success(context, 'Address saved');
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go(RoutePaths.home);
      }
    } catch (e, stack) {
      // Surface the real reason — "Session expired", "Latitude is required",
      // "Could not reach the server" — instead of a generic line that hides
      // whether the fix is re-login, re-pin, or retry.
      AppLogger.error('address save failed', error: e, stackTrace: stack);
      if (!mounted) return;

      final failure = ErrorMapper.toFailure(e);
      AppToast.error(context, failure.message);

      // Saving an address is authenticated, so a dead session leaves the
      // customer stuck on a form that can never succeed. Send them to sign in
      // again rather than letting them retry into the same 401.
      if (failure is AuthFailure) {
        context.go(RoutePaths.login);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The map SDK reads its own key from the manifest / Info.plist at build
  /// time, so it is not gated on the Dart-side `MAPS_API_KEY` — that one only
  /// pays for the Places REST calls.
  Widget _map(BuildContext context) {
    const centre = GeolocatorLocationService.fallbackCentre;
    return AddressPickerMap(
      latitude: _latitude ?? centre.latitude,
      longitude: _longitude ?? centre.longitude,
      isLocating: _locating,
      isResolving: _resolvingPin,
      addressLine: _pinAddress,
      onCentreChanged: _onCentreChanged,
      onUseCurrentLocation: _useCurrentLocation,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit address' : 'Add address')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _map(context),
            const SizedBox(height: AppSpacing.md),
            PlaceSearchField(
              latitude: _latitude,
              longitude: _longitude,
              onPlaceSelected: _onPlaceSelected,
            ),
            if (_errors['location'] != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _errors['location']!,
                style: context.text.bodySmall!
                    .copyWith(color: context.colors.error),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Text('Save as', style: context.text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: AddressLabel.values
                  .map(
                    (label) => Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: _LabelChip(
                        label: label,
                        selected: label == _label,
                        onTap: () => setState(() => _label = label),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _flat,
                    label: 'Flat / house no.',
                    hint: 'e.g. 402',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextField(
                    controller: _block,
                    label: 'Block (optional)',
                    hint: 'e.g. B',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _colony,
              label: 'Colony / society (optional)',
              hint: 'e.g. Lakeview Residency',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _street,
              label: 'Street / area',
              hint: 'e.g. MG Road, Sector 12',
              errorText: _errors['street'],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _details,
              label: 'Landmark / directions (optional)',
              hint: 'e.g. Opposite the city library',
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _city,
                    label: 'City',
                    errorText: _errors['city'],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextField(
                    controller: _state,
                    label: 'State',
                    errorText: _errors['state'],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _zip,
                    label: 'Pincode',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    errorText: _errors['zipCode'],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextField(
                    controller: _phone,
                    label: 'Phone (optional)',
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    errorText: _errors['phone'],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: isEditing ? 'Update address' : 'Save address',
              isLoading: _saving,
              onPressed: _save,
            ),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              label: 'View saved addresses',
              expand: true,
              icon: Icons.bookmark_border_rounded,
              onPressed: () => context.push(RoutePaths.addresses),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AddressLabel label;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (label) {
        AddressLabel.home => Icons.home_rounded,
        AddressLabel.office => Icons.business_rounded,
        AddressLabel.other => Icons.place_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon,
              size: 15,
              color: selected
                  ? context.colors.primary
                  : context.semantic.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label.wireValue,
              style: context.text.labelMedium!.copyWith(
                color: selected
                    ? context.colors.primary
                    : context.semantic.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
