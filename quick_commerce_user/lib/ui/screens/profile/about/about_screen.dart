import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../splash/splash_screen.dart';
import '../privacy_policy/legal_document_screen.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(cmsPageProvider('about')).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            const Center(child: SuvioMark(size: 78, onPrimary: false)),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Text(
                page?.title.isNotEmpty == true ? page!.title : AppStrings.appName,
                style: context.text.displaySmall,
              ),
            ),
            if (page != null && page.version.isNotEmpty)
              Center(
                child: Text(
                  'Version ${page.version}',
                  style: context.text.bodySmall,
                ),
              ),
            const SizedBox(height: AppSpacing.xxl),
            if (page != null && page.content.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: context.semantic.surfaceAlt,
                borderRadius: AppRadii.rLg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Why we built this', style: context.text.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Text(page.content, style: context.text.bodyLarge),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Center(
              child: Text(
                '© ${DateTime.now().year} Appzeto Quick',
                style: context.text.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
