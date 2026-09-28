import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_durations.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

/// Segmented OTP field with auto-advance, backspace-to-previous and paste
/// support.
///
/// Length defaults to 4 because that is what the backend's verify-otp DTO
/// requires.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    required this.onChanged,
    this.length = 4,
    this.onCompleted,
    this.hasError = false,
    this.autofocus = true,
  });

  final int length;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;
  final bool hasError;
  final bool autofocus;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _nodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _nodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _value => _controllers.map((c) => c.text).join();

  void _onDigit(int index, String raw) {
    // A paste lands entirely in one box — spread it across the rest.
    if (raw.length > 1) {
      final digits = raw.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < widget.length; i++) {
        _controllers[i].text = i < digits.length ? digits[i] : '';
      }
      _nodes[(digits.length - 1).clamp(0, widget.length - 1)].requestFocus();
      _emit();
      return;
    }

    if (raw.isNotEmpty && index < widget.length - 1) {
      _nodes[index + 1].requestFocus();
    }
    if (raw.isEmpty && index > 0) {
      _nodes[index - 1].requestFocus();
    }
    _emit();
  }

  void _emit() {
    final value = _value;
    widget.onChanged(value);
    if (value.length == widget.length && !value.contains(' ')) {
      widget.onCompleted?.call(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: List.generate(widget.length, (index) {
        return Padding(
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: _OtpBox(
            controller: _controllers[index],
            focusNode: _nodes[index],
            autofocus: widget.autofocus && index == 0,
            hasError: widget.hasError,
            onChanged: (value) => _onDigit(index, value),
          ),
        );
      }),
    );
  }
}

class _OtpBox extends StatefulWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.hasError,
    required this.autofocus,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool hasError;
  final bool autofocus;

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final focused = widget.focusNode.hasFocus;
    final filled = widget.controller.text.isNotEmpty;

    final borderColor = widget.hasError
        ? context.colors.error
        : focused
            ? context.colors.primary
            : filled
                ? context.colors.primary.withValues(alpha: 0.4)
                : context.semantic.border;

    return AnimatedContainer(
      duration: AppDurations.fast,
      height: 58,
      width: 52,
      decoration: BoxDecoration(
        color: context.semantic.surfaceAlt,
        borderRadius: AppRadii.rMd,
        border: Border.all(color: borderColor, width: focused ? 1.8 : 1.2),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: context.text.headlineSmall,
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}
