import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/model/category.dart';
import '../../../../navigation/route_paths.dart';
import '../../../common/smart_scan.dart';
import '../../../common/widgets/cards/category_card.dart';
import '../../../common/widgets/inputs/search_bar_widget.dart';
import '../../../common/widgets/loaders/list_skeleton.dart';
import '../../../common/widgets/misc/sound_refresh_indicator.dart';
import '../../../common/widgets/misc/staggered_entrance.dart';
import '../../../common/widgets/states/empty_state_widget.dart';
import '../../../common/widgets/states/error_state_widget.dart';
import '../../home/widgets/delivery_header.dart';
import 'categories_provider.dart';

/// Categories Screen matching reference Blinkit-style UI design:
/// - Golden top header gradient with delivery header & search bar.
/// - Grouped section headers ("Grocery & Kitchen", "Snacks & Drinks", etc.).
/// - 4-column grid of soft pastel mint category cards.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key, this.showAppBar = false});

  final bool showAppBar;

  Map<String, List<Category>> _groupCategories(List<Category> all) {
    final Map<String, List<Category>> groups = {
      'Grocery & Kitchen': [],
      'Snacks & Drinks': [],
      'Beauty & Personal Care': [],
      'Household Essentials': [],
    };

    for (final cat in all) {
      final name = cat.name.toLowerCase();
      if (name.contains('veg') ||
          name.contains('fruit') ||
          name.contains('atta') ||
          name.contains('rice') ||
          name.contains('dal') ||
          name.contains('oil') ||
          name.contains('ghee') ||
          name.contains('masala') ||
          name.contains('dairy') ||
          name.contains('bread') ||
          name.contains('egg') ||
          name.contains('bakery') ||
          name.contains('biscuit') ||
          name.contains('dry fruit') ||
          name.contains('cereal') ||
          name.contains('chicken') ||
          name.contains('meat') ||
          name.contains('fish') ||
          name.contains('kitchen')) {
        groups['Grocery & Kitchen']!.add(cat);
      } else if (name.contains('chip') ||
          name.contains('namkeen') ||
          name.contains('sweet') ||
          name.contains('choc') ||
          name.contains('drink') ||
          name.contains('juice') ||
          name.contains('tea') ||
          name.contains('coffee') ||
          name.contains('milk') ||
          name.contains('instant') ||
          name.contains('sauce') ||
          name.contains('spread') ||
          name.contains('paan') ||
          name.contains('ice cream') ||
          name.contains('snack')) {
        groups['Snacks & Drinks']!.add(cat);
      } else if (name.contains('beauty') ||
          name.contains('bath') ||
          name.contains('body') ||
          name.contains('hair') ||
          name.contains('skin') ||
          name.contains('baby') ||
          name.contains('cosmetic')) {
        groups['Beauty & Personal Care']!.add(cat);
      } else {
        groups['Household Essentials']!.add(cat);
      }
    }

    groups.removeWhere((key, value) => value.isEmpty);

    if (groups.isEmpty) {
      groups['All Categories'] = all;
    }
    return groups;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: context.colors.surface,
        appBar: showAppBar
            ? AppBar(title: const Text('All Categories'), elevation: 0)
            : null,
        body: Column(
          children: [
            // Golden Header Gradient with DeliveryHeader + SearchBar
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF24665E),
                    Color(0xFF43B5A8),
                    Color(0xFF82CEC5),
                    Color(0xFFC1E6E2),
                    Colors.white,
                  ],
                  // colors: [
                  //   Color(0xFFFFB300),
                  //   Color(0xFFFFC107),
                  //   Color(0xFFFFD54F),
                  //   Color(0xFFFFF8E1),
                  //   Colors.white,
                  // ],
                  stops: [0.0, 0.4, 0.7, 0.9, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                bottom: false,
                top: !showAppBar,
                child: Column(
                  children: [
                    const DeliveryHeader(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
                      child: SearchBarWidget(
                        readOnly: true,
                        hintRotation: const [
                          'sugar',
                          'Milk',
                          'Fresh Vegetables',
                          'Atta & Rice',
                        ],
                        onTap: () => context.push(RoutePaths.search),
                        onScanTap: () => SmartScan.run(context, ref),
                        onMicTap: () =>
                            context.push('${RoutePaths.search}?voice=1'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Main Category Grid Sections Content
            Expanded(
              child: categoriesAsync.when(
                loading: () =>
                    const CategoryGridSkeleton(count: 12, columns: 4),
                error: (error, _) => ErrorStateWidget(
                  failure: ErrorMapper.toFailure(error),
                  onRetry: () => ref.invalidate(categoriesProvider),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.category_outlined,
                      title: 'No categories yet',
                      message:
                          'Our catalog is being set up for your area. Check back shortly.',
                    );
                  }

                  final grouped = _groupCategories(items);

                  return SoundRefreshIndicator(
                    onRefresh: () async => ref.invalidate(categoriesProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                      itemCount: grouped.length,
                      itemBuilder: (context, sectionIndex) {
                        final sectionTitle = grouped.keys.elementAt(
                          sectionIndex,
                        );
                        final sectionCategories = grouped[sectionTitle]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(2, 12, 2, 10),
                              child: Text(
                                sectionTitle,
                                style: context.text.titleLarge!.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: const Color(0xFF1F2937),
                                ),
                              ),
                            ),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: sectionCategories.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    mainAxisSpacing: 16,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: 0.70,
                                  ),
                              itemBuilder: (context, index) {
                                final category = sectionCategories[index];
                                return StaggeredEntrance(
                                  index: index,
                                  child: CategoryCard(
                                    category: category,
                                    size: 74,
                                    onTap: () => context.push(
                                      RoutePaths.subCategoryOf(category.id),
                                      extra: category,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 6),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
