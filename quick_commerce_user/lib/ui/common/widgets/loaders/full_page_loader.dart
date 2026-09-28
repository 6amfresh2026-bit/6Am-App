import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

/// Used only where no skeleton shape is meaningful (splash, payment handoff).
class FullPageLoader extends StatelessWidget {
  const FullPageLoader({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            height: 34,
            width: 34,
            child: CircularProgressIndicator(strokeWidth: 2.8),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(message!, style: context.text.bodyMedium),
          ],
        ],
      ),
    );
  }
}
