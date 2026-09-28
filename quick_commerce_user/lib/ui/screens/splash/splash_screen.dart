import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_durations.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/local_storage/local_storage.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../di/app_providers.dart';
import '../../../di/repository_providers.dart';
import '../../../navigation/route_paths.dart';

/// Brand animation while we decide where the user actually belongs.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.slow,
  )..forward();

  @override
  void initState() {
    super.initState();
    _decideRoute();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _decideRoute() async {
    final storage = ref.read(localStorageProvider);
    await Future<void>.delayed(AppDurations.splashHold);
    if (!mounted) return;

    final seenOnboarding = storage.getBool(StorageKeys.onboardingSeen) ?? false;
    if (!seenOnboarding) {
      context.go(RoutePaths.onboarding);
      return;
    }

    if (!ref.read(authRepositoryProvider).isSignedIn) {
      context.go(RoutePaths.login);
      return;
    }

    // Signed in but the sign-up never finished — the app was closed on the
    // details screen. Ask again rather than letting a nameless account shop.
    final cached = ref.read(authRepositoryProvider).cachedUser;
    if (cached != null && cached.needsRegistrationDetails) {
      context.go(RoutePaths.register);
      return;
    }

    // Signed in: Home handles the missing-address case with its own prompt.
    await ref.read(addressBookProvider.notifier).load();
    if (!mounted) return;

    context.go(RoutePaths.home);
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/splash.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          Center(
            child: FadeTransition(
              opacity: fade,
              child: ScaleTransition(
                scale: Tween(begin: 0.82, end: 1.0).animate(
                  CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0),
                  child: Image.asset("assets/images/logo.png"),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Suvio brand mark: a bolt inside a rounded basket silhouette.
class SuvioMark extends StatelessWidget {
  const SuvioMark({super.key, this.size = 64, this.onPrimary = true});

  final double size;
  final bool onPrimary;

  @override
  Widget build(BuildContext context) {
    // On the brand plate the mark is drawn in the on-primary ink; off it, in
    // the brand colour itself.
    final foreground = onPrimary
        ? context.colors.onPrimary
        : context.colors.primary;
    final background = foreground.withValues(alpha: onPrimary ? 0.12 : 0.10);

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.30),
        border: Border.all(color: foreground.withValues(alpha: 0.5), width: 2),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.bolt_rounded, size: size * 0.52, color: foreground),
    );
  }
}

/// Small inline lockup used in app bars and the About screen.
class SuvioWordmark extends StatelessWidget {
  const SuvioWordmark({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: context.colors.primary,
            borderRadius: AppRadii.rSm,
          ),
          child: Icon(
            Icons.bolt_rounded,
            size: 15,
            color: context.colors.onPrimary,
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(AppStrings.appName, style: context.text.titleLarge),
        ],
      ],
    );
  }
}
