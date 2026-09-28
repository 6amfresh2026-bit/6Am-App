import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

class OnboardingSlideData {
  const OnboardingSlideData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

/// Illustration stand-in built from theme tokens — no bundled artwork needed,
/// and it recolours correctly with the selected brand flavour and dark mode.
class OnboardingSlide extends StatelessWidget {
  const OnboardingSlide({super.key, required this.data});

  final OnboardingSlideData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 240,
            width: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const _Ring(size: 240, opacity: 0.05),
                const _Ring(size: 182, opacity: 0.08),
                const _Ring(size: 124, opacity: 0.12),
                Icon(data.icon, size: 62, color: context.colors.primary),
                Positioned(
                  top: 34,
                  right: 30,
                  child: _Pip(color: context.semantic.accent, size: 14),
                ),
                Positioned(
                  bottom: 44,
                  left: 26,
                  child: _Pip(color: context.colors.primary, size: 9),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: context.text.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: context.text.bodyLarge!
                .copyWith(color: context.semantic.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: context.colors.primary.withValues(alpha: opacity),
          shape: BoxShape.circle,
        ),
      );
}

class _Pip extends StatelessWidget {
  const _Pip({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        height: size,
        width: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
