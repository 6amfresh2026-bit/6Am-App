import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_durations.dart';
import '../../../core/local_storage/local_storage.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../di/repository_providers.dart';
import '../../../navigation/route_paths.dart';
import '../../common/widgets/buttons/primary_button.dart';
import 'widgets/onboarding_slide.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _slides = [
    OnboardingSlideData(
      icon: Icons.bolt_rounded,
      title: 'Groceries in minutes',
      body:
          'Order what you need and we will have it at your door before the kettle boils.',
    ),
    OnboardingSlideData(
      icon: Icons.eco_rounded,
      title: 'Fresh, every single time',
      body:
          'Produce is picked the same day and packed cold, so it arrives the way it left.',
    ),
    OnboardingSlideData(
      icon: Icons.savings_rounded,
      title: 'Prices you can trust',
      body:
          'Clear bills, real discounts and no surprise fees at checkout. Ever.',
    ),
  ];

  bool get _isLast => _index == _slides.length - 1;

  Future<void> _finish() async {
    await ref
        .read(localStorageProvider)
        .setBool(StorageKeys.onboardingSeen, true);
    if (mounted) context.go(RoutePaths.login);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: TextButton(
                  onPressed: _finish,
                  child: Text('Skip', style: context.text.labelLarge),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, index) =>
                    OnboardingSlide(data: _slides[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (i) => _Dot(active: i == _index),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: _isLast ? 'Get started' : 'Next',
                    onPressed: () {
                      if (_isLast) {
                        _finish();
                        return;
                      }
                      _controller.nextPage(
                        duration: AppDurations.medium,
                        curve: Curves.easeOutCubic,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.medium,
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      height: 6,
      width: active ? 22 : 6,
      decoration: BoxDecoration(
        color: active ? context.colors.primary : context.semantic.border,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
