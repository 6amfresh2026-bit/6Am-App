import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../buttons/primary_button.dart';

/// Confirmation dialog for destructive or blocking decisions.
abstract final class AppDialog {
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = AppStrings.cancel,
    bool destructive = false,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: icon == null
            ? null
            : Icon(
                icon,
                size: 32,
                color: destructive
                    ? context.semantic.danger
                    : context.colors.primary,
              ),
        title: Text(title),
        content: Text(message),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    cancelLabel,
                    style: context.text.labelLarge!
                        .copyWith(color: context.semantic.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: PrimaryButton(
                  label: confirmLabel,
                  destructive: destructive,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
