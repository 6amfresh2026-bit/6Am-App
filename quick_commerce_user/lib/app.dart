import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_provider.dart';
import 'navigation/app_router.dart';
import 'platform/notification/push_listener.dart';

class SuvioQuickApp extends ConsumerWidget {
  const SuvioQuickApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(appRouterProvider),
      themeMode: theme.mode,
      theme: AppTheme.light(theme.flavor),
      darkTheme: AppTheme.dark(theme.flavor),
      builder: (context, child) {
        // Cap text scaling: quick-commerce cards are dense, and beyond ~1.3
        // the price and the ADD button start colliding.
        final scale = MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.3,
        );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          child: PushListener(child: child!),
        );
      },
    );
  }
}
