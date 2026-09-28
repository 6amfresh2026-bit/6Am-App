import 'package:flutter/material.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

/// Address / delivery / payment summary row on the checkout screen.
///
/// The action is optional: some rows state a fact the customer cannot change,
/// such as the delivery promise.
class CheckoutSectionCard extends StatelessWidget {
  const CheckoutSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Draws attention when the section still needs input.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadii.rLg,
        border: Border.all(
          color: highlight ? context.semantic.danger : context.semantic.border,
          width: highlight ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.08),
              borderRadius: AppRadii.rSm,
            ),
            child: Icon(icon, size: 18, color: context.colors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleMedium),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          if (onAction != null && actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: context.text.labelMedium!
                    .copyWith(color: context.colors.primary),
              ),
            ),
        ],
      ),
    );
  }
}
