import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';

/// Title + optional "See all" above every home/listing section.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeAll,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(12, 6, 12, 2),
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;

  /// Replaces "See all" — used by the flash-sale countdown.
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.sectionHeader),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(subtitle!, style: context.text.bodySmall),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Text(
                      'See all',
                      style: context.text.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: context.semantic.success),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: context.semantic.success,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
