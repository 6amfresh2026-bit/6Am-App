import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../di/repository_providers.dart';
import '../../../../domain/model/cms_page.dart';
import '../../../common/widgets/states/empty_state_widget.dart';
import '../../../common/widgets/states/error_state_widget.dart';
import '../../../../core/errors/error_mapper.dart';

/// CMS page by key — `terms`, `privacy`, `about`, … from `/food/pages/:key`.
final cmsPageProvider = FutureProvider.family<CmsPage?, String>(
  (ref, key) => ref.watch(catalogContentRepositoryProvider).page(key),
);

/// Shared typesetting for Privacy Policy and Terms — same structure, different
/// key, so one screen serves both. All copy comes from the backend CMS.
class LegalDocumentScreen extends ConsumerWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.pageKey,
  });

  final String title;
  final String pageKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(cmsPageProvider(pageKey));

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: page.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorStateWidget(
            failure: ErrorMapper.toFailure(e),
            onRetry: () => ref.invalidate(cmsPageProvider(pageKey)),
          ),
          data: (page) => page == null
              ? EmptyStateWidget(
                  icon: Icons.description_outlined,
                  title: title,
                  message: 'This document has not been published yet.',
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  children: [
                    Text(
                      page.title.isEmpty ? title : page.title,
                      style: context.text.displaySmall,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      plainTextFromHtml(page.content),
                      style: context.text.bodyLarge!.copyWith(height: 1.6),
                    ),
                    if (page.email.isNotEmpty || page.mobile.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        [page.email, page.mobile]
                            .where((v) => v.isNotEmpty)
                            .join('  ·  '),
                        style: context.text.bodySmall,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
        ),
      ),
    );
  }
}

/// The CMS stores rich text; this screen renders plain paragraphs.
// ponytail: tag strip, swap for an HTML renderer if the CMS starts using
// tables or links that matter.
String plainTextFromHtml(String html) => html
    .replaceAll(RegExp(r'<br\s*/?>|</p>|</div>|</li>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();
