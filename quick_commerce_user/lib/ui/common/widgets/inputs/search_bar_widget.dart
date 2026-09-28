import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

/// The search field. Features vertical page-up changing text animation for
/// top categories / products.
class SearchBarWidget extends StatefulWidget {
  const SearchBarWidget({
    super.key,
    this.controller,
    this.onTap,
    this.onScanTap,
    this.onMicTap,
    this.onChanged,
    this.onSubmitted,
    this.readOnly = false,
    this.autofocus = false,
    this.categories = const [],
    this.hintRotation = const [
      'Milk',
      'Curd & Yogurt',
      'Fresh Vegetables',
      'Fresh Fruits',
      'Atta & Flour',
      'Biscuits & Chips',
      'Tea & Coffee',
      'Soft Drinks',
    ],
  });

  final TextEditingController? controller;
  final VoidCallback? onTap;

  /// Tapped when the scanner icon is pressed (opens the camera scanner).
  final VoidCallback? onScanTap;

  /// Tapped when the microphone icon is pressed (starts voice search).
  final VoidCallback? onMicTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool readOnly;
  final bool autofocus;

  /// Top category names to cycle through.
  final List<String> categories;

  /// Default rotating placeholders when categories list is empty.
  final List<String> hintRotation;

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  int _currentIndex = 0;
  Timer? _timer;

  List<String> get _items {
    if (widget.categories.isNotEmpty) {
      return widget.categories;
    }
    return widget.hintRotation;
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
    widget.controller?.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(SearchBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.categories != oldWidget.categories ||
        widget.hintRotation != oldWidget.hintRotation) {
      if (_currentIndex >= _items.length) {
        _currentIndex = 0;
      }
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_items.isEmpty) return;
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      final items = _items;
      if (items.isEmpty) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % items.length;
      });
    });
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    _timer?.cancel();
    super.dispose();
  }

  Widget _buildAnimatedHintText({required TextStyle style}) {
    final items = _items;
    final currentItem = items.isEmpty
        ? 'products, brands…'
        : items[_currentIndex % items.length];
    final displayText = 'Search "$currentItem"';

    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          final isIncoming =
              (child.key as ValueKey<int>?)?.value == _currentIndex;

          final inAnimation = Tween<Offset>(
            begin: const Offset(0.0, 1.2),
            end: Offset.zero,
          ).animate(animation);

          final outAnimation = Tween<Offset>(
            begin: const Offset(0.0, -1.2),
            end: Offset.zero,
          ).animate(animation);

          return SlideTransition(
            position: isIncoming ? inAnimation : outAnimation,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        child: Align(
          key: ValueKey<int>(_currentIndex),
          alignment: Alignment.centerLeft,
          child: Text(
            displayText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );

    final hintStyle = context.text.titleMedium!.copyWith(
      fontWeight: FontWeight.w400,
      fontSize: 14,
      color: const Color(0xFF6B7280),
    );

    if (widget.readOnly) {
      return GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 44,
          decoration: decoration,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                size: 24,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAnimatedHintText(style: hintStyle),
              ),
              if (widget.onMicTap != null)
                GestureDetector(
                  onTap: widget.onMicTap,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Icon(
                      Icons.mic_none_rounded,
                      size: 22,
                      color: Color(0xFF43B5A8),
                      // color: Color(0xFFFFC107),
                    ),
                  ),
                ),
              GestureDetector(
                onTap: widget.onScanTap,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 22,
                    color: Color(0xFF43B5A8),
                    // color: Color(0xFFFFC107),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final hasText = (widget.controller?.text ?? '').isNotEmpty;

    return Container(
      height: 48,
      decoration: decoration,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: context.semantic.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                if (!hasText)
                  IgnorePointer(
                    child: _buildAnimatedHintText(
                      style: context.text.bodyLarge!
                          .copyWith(color: context.semantic.textSecondary),
                    ),
                  ),
                TextField(
                  controller: widget.controller,
                  autofocus: widget.autofocus,
                  textInputAction: TextInputAction.search,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  style: context.text.bodyLarge,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          if (hasText)
            IconButton(
              onPressed: () {
                widget.controller?.clear();
                widget.onChanged?.call('');
              },
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: 'Clear',
            ),
          if (widget.onMicTap != null)
            IconButton(
              onPressed: widget.onMicTap,
              icon: const Icon(Icons.mic_none_rounded, size: 20),
              color: const Color(0xFF43B5A8),
              // color: Color(0xFFFFC107),
              tooltip: 'Voice search',
            ),
        ],
      ),
    );
  }
}
