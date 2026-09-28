import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

/// Labelled text field with inline error text.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.keyboardType,
    this.inputFormatters,
    this.prefix,
    this.suffix,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.sentences,
    this.focusNode,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefix;
  final Widget? suffix;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: context.text.titleSmall),
          const SizedBox(height: AppSpacing.sm),
        ],
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          autofocus: autofocus,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          maxLength: maxLength,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: context.text.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefix,
            suffixIcon: suffix,
            counterText: '',
            errorText: errorText,
            errorStyle: context.text.bodySmall!
                .copyWith(color: context.colors.error),
          ),
        ),
      ],
    );
  }
}
