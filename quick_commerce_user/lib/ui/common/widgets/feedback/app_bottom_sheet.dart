import 'package:flutter/material.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

/// Shared bottom-sheet chrome: drag handle, rounded top, safe-area aware,
/// swipe-to-dismiss. Every sheet in the app goes through [show].
abstract final class AppBottomSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Widget child,
    String? subtitle,
    Widget? footer,
    bool isDismissible = true,
    bool expand = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SheetShell(
        title: title,
        subtitle: subtitle,
        footer: footer,
        expand: expand,
        child: child,
      ),
    );
  }
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({
    required this.title,
    required this.child,
    this.subtitle,
    this.footer,
    this.expand = false,
  });

  final String title;
  final Widget child;
  final String? subtitle;
  final Widget? footer;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadii.sheetTop,
        boxShadow: context.semantic.sheetShadow,
      ),
      child: Column(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          const _DragHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              20.0,
              AppSpacing.xs,
              12.0,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: context.text.headlineSmall),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(subtitle!, style: context.text.bodySmall),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          Flexible(child: child),
          if (footer != null)
            Container(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                AppSpacing.lg + MediaQuery.viewPaddingOf(context).bottom,
              ),
              decoration: BoxDecoration(
                color: context.colors.surface,
                border: Border(top: BorderSide(color: context.semantic.border)),
              ),
              child: footer,
            ),
        ],
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Container(
          height: 4,
          width: 40,
          decoration: BoxDecoration(
            color: context.semantic.border,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );
}
