import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_durations.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../di/app_providers.dart';

/// Slim bar that appears whenever connectivity drops.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(isOfflineProvider);

    return AnimatedSize(
      duration: AppDurations.medium,
      curve: Curves.easeOut,
      child: offline
          // Screens place this above their own SafeArea, so it has to inset
          // itself — without this the text sits under the status bar clock.
          ? Container(
              width: double.infinity,
              color: context.semantic.warningSoft,
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm + MediaQuery.paddingOf(context).top,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 15,
                    color: context.semantic.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      AppStrings.offline,
                      style: context.text.labelMedium!
                          .copyWith(color: context.semantic.warning),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}
