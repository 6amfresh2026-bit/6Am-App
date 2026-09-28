import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_durations.dart';
import '../../../../../core/theme/app_radii.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/debouncer.dart';
import '../../../../../di/repository_providers.dart';
import '../../../../../domain/model/place.dart';

/// Google Places autocomplete for the address form.
///
/// Keystrokes are debounced and share one billing session token, so typing an
/// address is charged as a single Places session rather than per character.
class PlaceSearchField extends ConsumerStatefulWidget {
  const PlaceSearchField({
    super.key,
    required this.onPlaceSelected,
    this.latitude,
    this.longitude,
  });

  final void Function(ResolvedPlace place) onPlaceSelected;

  /// Biases results toward the map's current centre.
  final double? latitude;
  final double? longitude;

  @override
  ConsumerState<PlaceSearchField> createState() => _PlaceSearchFieldState();
}

class _PlaceSearchFieldState extends ConsumerState<PlaceSearchField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _debouncer = Debouncer(AppDurations.searchDebounce);

  List<PlaceSuggestion> _suggestions = const [];
  bool _isSearching = false;
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    // One session token per editing session; Google bills the autocomplete
    // calls plus the final details call as a single unit.
    ref.read(googlePlaceRepositoryProvider).startSession(
          'sess-${DateTime.now().microsecondsSinceEpoch}',
        );
  }

  @override
  void dispose() {
    ref.read(googlePlaceRepositoryProvider).endSession();
    _debouncer.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (value.trim().length < 3) {
      _debouncer.cancel();
      setState(() {
        _suggestions = const [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _debouncer.run(() async {
      final results = await ref.read(placeRepositoryProvider).autocomplete(
            value,
            latitude: widget.latitude,
            longitude: widget.longitude,
          );
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    });
  }

  Future<void> _select(PlaceSuggestion suggestion) async {
    setState(() {
      _isResolving = true;
      _suggestions = const [];
    });
    _controller.text = suggestion.fullText;
    _focusNode.unfocus();

    final place = await ref.read(placeRepositoryProvider).details(suggestion.placeId);
    if (!mounted) return;

    setState(() => _isResolving = false);
    if (place != null) widget.onPlaceSelected(place);

    // The details call closed the previous session; open a fresh one in case
    // the user searches again without leaving the screen.
    ref.read(googlePlaceRepositoryProvider).startSession(
          'sess-${DateTime.now().microsecondsSinceEpoch}',
        );
  }

  @override
  Widget build(BuildContext context) {
    final mapsEnabled = ref.watch(appConfigProvider).hasMapsKey;
    if (!mapsEnabled) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: AppRadii.rMd,
            border: Border.all(color: context.semantic.border),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 19,
                color: context.semantic.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: _onChanged,
                  textInputAction: TextInputAction.search,
                  style: context.text.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Search a building, street or area',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintStyle: context.text.bodyLarge!
                        .copyWith(color: context.semantic.textSecondary),
                  ),
                ),
              ),
              if (_isSearching || _isResolving)
                const SizedBox(
                  height: 15,
                  width: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_controller.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _controller.clear();
                    _onChanged('');
                  },
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: context.semantic.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.sm),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: AppRadii.rMd,
              border: Border.all(color: context.semantic.border),
              boxShadow: context.semantic.cardShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final suggestion in _suggestions.take(5))
                  InkWell(
                    onTap: () => _select(suggestion),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 17,
                            color: context.semantic.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  suggestion.primaryText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.titleSmall,
                                ),
                                if (suggestion.secondaryText.isNotEmpty)
                                  Text(
                                    suggestion.secondaryText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.text.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
