import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../di/app_providers.dart';
import '../../../domain/model/category.dart';
import '../../../domain/model/product.dart';
import '../../../navigation/route_paths.dart';
import '../../common/smart_scan.dart';
import '../../common/voice_search.dart';
import '../../common/widgets/misc/app_network_image.dart';
import '../../common/widgets/states/empty_state_widget.dart';
import '../../common/widgets/states/error_state_widget.dart';
import '../home/home_provider.dart';
import 'search_provider.dart';
import 'search_state.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.autoStartVoice = false});

  final bool autoStartVoice;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final position = _scrollController.position;
      if (position.pixels >= position.maxScrollExtent * 0.8) {
        ref.read(searchProvider.notifier).loadMore();
      }
    });
    if (widget.autoStartVoice) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startVoiceSearch());
    }
  }

  Future<void> _startVoiceSearch() async {
    final spoken = await VoiceSearch.run(context);
    if (spoken == null || !mounted) return;
    _runQuery(spoken);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _runQuery(String query) {
    _controller.text = query;
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
    ref.read(searchProvider.notifier)
      ..onQueryChanged(query)
      ..commitSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);
    final cartCount = ref.watch(cartItemCountProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FCFA),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Search Header
            _buildSearchHeader(context, cartCount),

            const SizedBox(height: 10),

            // 2. Search Body (Idle or Results)
            Expanded(child: _buildBody(context, state)),
          ],
        ),
      ),
    );
  }

  /// Top Search Bar matching reference design
  Widget _buildSearchHeader(BuildContext context, int cartCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          // Back Button
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFE6F4EE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF00875A),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Search Box Input
          Expanded(
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF475569),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search products, brands...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF94A3B8),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged:
                          ref.read(searchProvider.notifier).onQueryChanged,
                      onSubmitted:
                          ref.read(searchProvider.notifier).commitSearch,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => SmartScan.run(context, ref),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: const Color(0xFF00875A), width: 1.5),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Color(0xFF00875A),
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Cart Bell Icon with Red Badge Dot
          GestureDetector(
            onTap: () => context.go(RoutePaths.cart),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE6F4EE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: Color(0xFF00875A),
                    size: 22,
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$cartCount',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, SearchState state) {
    if (state.showIdleState) return _buildIdleState(context, state);

    if (state.isLoading && state.results.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00875A)),
      );
    }
    if (state.failure != null && state.results.isEmpty) {
      return ErrorStateWidget(
        failure: state.failure!,
        onRetry: () => ref.read(searchProvider.notifier).search(state.query),
      );
    }
    if (state.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.search_off_rounded,
        title: 'No results for "${state.query}"',
        message:
            'Check the spelling, or try one of the popular categories below.',
        actionLabel: 'Browse categories',
        onAction: () => context.go(RoutePaths.categories),
      );
    }

    return _buildSearchResults(context, state);
  }

  /// 100% Dynamic Idle search view
  Widget _buildIdleState(BuildContext context, SearchState state) {
    final homeState = ref.watch(homeProvider);
    final categories = homeState.categories;
    final recentSearches = state.recentSearches;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Dynamic Recent Searches (rendered only if user has recent searches)
          if (recentSearches.isNotEmpty) ...[
            Text(
              'Recent Searches',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recentSearches.map((term) {
                return GestureDetector(
                  onTap: () => _runQuery(term),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      term,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // 2. Dynamic Popular Categories (Full Circle Icons)
          if (categories.isNotEmpty) ...[
            Text(
              'Popular Categories',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            _buildPopularCategoriesRow(context, categories),
            const SizedBox(height: 24),
          ],

          // 3. Dynamic Trending Products Section
          Text(
            'Trending Products',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          _buildTrendingProductsList(context, homeState),
        ],
      ),
    );
  }

  /// Popular categories full circle horizontal strip (Dynamic from backend)
  Widget _buildPopularCategoriesRow(
    BuildContext context,
    List<Category> categories,
  ) {
    final colors = [
      const Color(0xFFFFF1F2),
      const Color(0xFFECFDF5),
      const Color(0xFFEFF6FF),
      const Color(0xFFFFF7ED),
      const Color(0xFFF0F9FF),
    ];

    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final Color bgColor = colors[index % colors.length];

          return GestureDetector(
            onTap: () => context.push(RoutePaths.subCategoryOf(cat.id)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: AppNetworkImage(
                      url: cat.imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      fallbackIcon: Icons.category_rounded,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 64,
                  child: Text(
                    cat.name,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Trending products vertical list (Dynamic from real catalog)
  Widget _buildTrendingProductsList(BuildContext context, dynamic homeState) {
    final List<Product> trendingProducts = homeState.sections.isNotEmpty
        ? homeState.sections.first.products
        : <Product>[];

    if (trendingProducts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF00875A)),
        ),
      );
    }

    return Column(
      children: trendingProducts.map((product) {
        return GestureDetector(
          onTap: () => context.push(
            RoutePaths.productDetailsOf(product.id),
            extra: product,
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AppNetworkImage(
                    url: product.imageUrl,
                    fit: BoxFit.contain,
                    fallbackIcon: Icons.shopping_bag_outlined,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${product.price.toStringAsFixed(0)}',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                  size: 22,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Search Results grid
  Widget _buildSearchResults(BuildContext context, SearchState state) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: state.results.length,
      itemBuilder: (context, index) {
        final product = state.results[index];
        return GestureDetector(
          onTap: () {
            ref.read(searchProvider.notifier).commitSearch(state.query);
            context.push(
              RoutePaths.productDetailsOf(product.id),
              extra: product,
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AppNetworkImage(
                    url: product.imageUrl,
                    fit: BoxFit.contain,
                    fallbackIcon: Icons.shopping_bag_outlined,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '₹${product.price.toStringAsFixed(0)}',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          if (product.strikePrice != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '₹${product.strikePrice!.toStringAsFixed(0)}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF94A3B8),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00875A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'View',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
