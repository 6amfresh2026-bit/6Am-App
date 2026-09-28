import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_durations.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

enum ToastVariant { success, error, warning, info }

/// App-wide custom Toast helper. Replaces any existing active toast cleanly.
abstract final class AppToast {
  static _ToastEntryHandle? _activeToast;

  static void show(
    BuildContext context,
    String message, {
    ToastVariant variant = ToastVariant.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = AppDurations.toast,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    // Dismiss existing active toast if present
    _activeToast?.dismiss();

    late final _ToastEntryHandle handle;
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) {
        return _AppToastWidget(
          message: message,
          variant: variant,
          actionLabel: actionLabel,
          onAction: onAction,
          duration: duration,
          onDismissed: () {
            entry.remove();
            if (_activeToast == handle) {
              _activeToast = null;
            }
          },
        );
      },
    );

    handle = _ToastEntryHandle(
      entry: entry,
      dismiss: () {
        if (_activeToast == handle) {
          entry.remove();
          _activeToast = null;
        }
      },
    );

    _activeToast = handle;
    overlay.insert(entry);
  }

  static void success(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      show(
        context,
        message,
        variant: ToastVariant.success,
        actionLabel: actionLabel,
        onAction: onAction,
      );

  static void error(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      show(
        context,
        message,
        variant: ToastVariant.error,
        actionLabel: actionLabel,
        onAction: onAction,
      );

  static void warning(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      show(
        context,
        message,
        variant: ToastVariant.warning,
        actionLabel: actionLabel,
        onAction: onAction,
      );

  static void info(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      show(
        context,
        message,
        variant: ToastVariant.info,
        actionLabel: actionLabel,
        onAction: onAction,
      );
}

class _ToastEntryHandle {
  final OverlayEntry entry;
  final VoidCallback dismiss;

  _ToastEntryHandle({required this.entry, required this.dismiss});
}

class _AppToastWidget extends StatefulWidget {
  final String message;
  final ToastVariant variant;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final VoidCallback onDismissed;

  const _AppToastWidget({
    required this.message,
    required this.variant,
    this.actionLabel,
    this.onAction,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_AppToastWidget> createState() => _AppToastWidgetState();
}

class _AppToastWidgetState extends State<_AppToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  Timer? _dismissTimer;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.toastAnimation,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    // Negative Y so it slides down into place from above and retracts upward
    // on dismiss — matching the new top anchor.
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _controller.forward();

    _dismissTimer = Timer(widget.duration, _dismiss);
  }

  void _dismiss() {
    if (_isDismissing || !mounted) return;
    _isDismissing = true;
    _dismissTimer?.cancel();
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismissed();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    final icon = switch (widget.variant) {
      ToastVariant.success => Icons.check_circle_rounded,
      ToastVariant.error => Icons.error_rounded,
      ToastVariant.warning => Icons.warning_rounded,
      ToastVariant.info => Icons.info_rounded,
    };

    // Below the status bar/notch AND a standard app bar, so it never overlaps
    // either. `kToolbarHeight` is the Material app-bar height; screens without
    // an app bar just get the toast a little lower, still clearly at the top.
    // ponytail: fixed app-bar clearance — a global overlay can't read each
    // screen's actual app bar; revisit if a screen uses a taller bar.
    final topOffset =
        MediaQuery.of(context).padding.top + kToolbarHeight + 8.0;

    return Positioned(
      top: topOffset,
      left: AppSpacing.lg,
      right: AppSpacing.lg,
      child: Material(
        type: MaterialType.transparency,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md + 2,
              ),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: AppRadii.rMd,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: context.text.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ) ??
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  if (widget.actionLabel != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    GestureDetector(
                      onTap: () {
                        widget.onAction?.call();
                        _dismiss();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: AppSpacing.xs,
                        ),
                        child: Text(
                          widget.actionLabel!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
