import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../buttons/primary_button.dart';

/// Shared failure state. Takes a [Failure] so raw exception text never reaches
/// a customer.
class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    super.key,
    required this.failure,
    this.onRetry,
    this.compact = false,
  });

  final Failure failure;
  final VoidCallback? onRetry;
  final bool compact;

  IconData get _icon => switch (failure) {
        NetworkFailure() => Icons.wifi_off_rounded,
        TimeoutFailure() => Icons.hourglass_empty_rounded,
        AuthFailure() => Icons.lock_outline_rounded,
        NotFoundFailure() => Icons.search_off_rounded,
        ValidationFailure() => Icons.error_outline_rounded,
        ServerFailure() => Icons.cloud_off_rounded,
        UnknownFailure() => Icons.error_outline_rounded,
      };

  String get _title => switch (failure) {
        NetworkFailure() => 'No connection',
        TimeoutFailure() => 'That took too long',
        AuthFailure() => 'Please sign in again',
        NotFoundFailure() => 'Not found',
        ValidationFailure() => 'We could not do that',
        ServerFailure() => 'Our servers are busy',
        UnknownFailure() => AppStrings.somethingWentWrong,
      };

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: compact ? 60 : 88,
              width: compact ? 60 : 88,
              decoration: BoxDecoration(
                color: context.semantic.dangerSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _icon,
                size: compact ? 28 : 38,
                color: context.semantic.danger,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(_title, style: context.text.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              failure.message,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: AppStrings.retry,
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
