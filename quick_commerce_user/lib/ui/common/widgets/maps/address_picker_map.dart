import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/constants/app_durations.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../buttons/secondary_button.dart';

/// Interactive map with a fixed centre pin.
///
/// The pin does not move — the map moves under it, which is the pattern every
/// delivery app uses because it keeps the target under the user's thumb. When
/// the camera settles, [onCentreChanged] fires so the caller can reverse-geocode.
class AddressPickerMap extends StatefulWidget {
  const AddressPickerMap({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.onCentreChanged,
    this.onUseCurrentLocation,
    this.isLocating = false,
    this.isResolving = false,
    this.addressLine = '',
    this.height = 260,
  });

  final double latitude;
  final double longitude;

  /// Fires once the camera has come to rest, never mid-drag.
  final void Function(double latitude, double longitude) onCentreChanged;

  final VoidCallback? onUseCurrentLocation;
  final bool isLocating;

  /// True while the caller is reverse-geocoding the current centre.
  final bool isResolving;
  final String addressLine;
  final double height;

  @override
  State<AddressPickerMap> createState() => _AddressPickerMapState();
}

class _AddressPickerMapState extends State<AddressPickerMap> {
  GoogleMapController? _controller;
  bool _isDragging = false;

  @override
  void didUpdateWidget(AddressPickerMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Recentre when the parent moves the pin (current location, or a chosen
    // search result). Skip while the user is dragging, or the map fights them.
    final moved = oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude;
    if (moved && !_isDragging) {
      _controller?.animateCamera(
        CameraUpdate.newLatLng(LatLng(widget.latitude, widget.longitude)),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadii.rLg,
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(widget.latitude, widget.longitude),
                zoom: 16.5,
              ),
              onMapCreated: (controller) => _controller = controller,
              onCameraMoveStarted: () => setState(() => _isDragging = true),
              onCameraIdle: () {
                setState(() => _isDragging = false);
                _emitCentre();
              },
              // The pin is drawn in the overlay, so the map itself carries none.
              markers: const {},
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              // Let the parent scroll view keep vertical drags unless the
              // gesture starts on the map.
              gestureRecognizers: const {},
            ),
            Center(
              child: Padding(
                // Lifts the pin tip onto the exact centre pixel.
                padding: const EdgeInsets.only(bottom: 34),
                child: _CentrePin(lifted: _isDragging),
              ),
            ),
            if (widget.addressLine.isNotEmpty || widget.isResolving)
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.md,
                child: _AddressChip(
                  text: widget.addressLine,
                  isLoading: widget.isResolving,
                ),
              ),
            if (widget.onUseCurrentLocation != null)
              Positioned(
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: SecondaryButton(
                  label: 'Use current location',
                  icon: Icons.my_location_rounded,
                  isLoading: widget.isLocating,
                  tonal: false,
                  onPressed: widget.onUseCurrentLocation,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _emitCentre() async {
    final controller = _controller;
    if (controller == null) return;

    final region = await controller.getVisibleRegion();
    final centre = LatLng(
      (region.northeast.latitude + region.southwest.latitude) / 2,
      (region.northeast.longitude + region.southwest.longitude) / 2,
    );
    widget.onCentreChanged(centre.latitude, centre.longitude);
  }
}

/// Pin that hops up while the map is moving, so it reads as hovering.
class _CentrePin extends StatelessWidget {
  const _CentrePin({required this.lifted});

  final bool lifted;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSlide(
          offset: lifted ? const Offset(0, -0.22) : Offset.zero,
          duration: AppDurations.fast,
          curve: Curves.easeOut,
          child: Icon(
            Icons.location_on_rounded,
            size: 46,
            color: context.colors.primary,
            shadows: const [Shadow(blurRadius: 8, color: Colors.black38)],
          ),
        ),
        AnimatedScale(
          scale: lifted ? 0.7 : 1,
          duration: AppDurations.fast,
          child: Container(
            height: 6,
            width: 24,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddressChip extends StatelessWidget {
  const _AddressChip({required this.text, required this.isLoading});

  final String text;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadii.rPill,
        boxShadow: context.semantic.cardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            const SizedBox(
              height: 12,
              width: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              Icons.location_on_rounded,
              size: 14,
              color: context.colors.primary,
            ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              isLoading ? 'Finding this address…' : text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}
