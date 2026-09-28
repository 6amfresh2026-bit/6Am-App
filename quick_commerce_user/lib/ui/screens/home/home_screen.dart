import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../di/app_providers.dart';
import '../../../domain/model/banner.dart';
import '../../../domain/model/product.dart';
import '../../../navigation/route_paths.dart';
import '../../common/smart_scan.dart';
import '../../common/widgets/misc/app_network_image.dart';
import '../../common/widgets/misc/sound_refresh_indicator.dart';
import '../../common/widgets/states/error_state_widget.dart';
import '../../common/widgets/states/offline_banner.dart';
import '../location/location_prompt/location_prompt_sheet.dart';
import '../product/product_listing/product_listing_args.dart';
import '../survey/survey_popup.dart';
import 'home_provider.dart';
import 'home_state.dart';
import 'widgets/active_order_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final ScrollController _scrollController;
  bool _promptsChecked = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _runPostSignInPrompts();
  }

  void _runPostSignInPrompts() {
    if (_promptsChecked) return;
    _promptsChecked = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !ref.read(authProvider).isSignedIn) return;
      await LocationPromptSheet.showIfNeeded(context, ref);
      if (!mounted) return;
      await SurveyPopup.showIfAvailable(context, ref);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeProvider);
    final selectedAddress = ref.watch(selectedAddressProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7FCFA),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  const OfflineBanner(),
                  Expanded(child: _buildBody(context, state, selectedAddress)),
                ],
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 4,
                child: ActiveOrderFloatingCard(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    HomeState state,
    dynamic selectedAddress,
  ) {
    if (state.failure != null &&
        state.sections.isEmpty &&
        state.categories.isEmpty) {
      return ErrorStateWidget(
        failure: state.failure!,
        onRetry: () => ref.read(homeProvider.notifier).load(refresh: true),
      );
    }

    final addressText = selectedAddress != null
        ? '${selectedAddress.street.isNotEmpty ? selectedAddress.street : selectedAddress.formattedAddress}'
        : 'Banjara Hills, Hyderabad';

    return SoundRefreshIndicator(
      onRefresh: () => ref.read(homeProvider.notifier).load(refresh: true),
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Location & Notification Header
            _buildHeader(context, addressText),

            const SizedBox(height: 16),

            // 2. Search Bar
            _buildSearchBar(context),

            const SizedBox(height: 16),

            // 3. Dynamic Banner Card
            _buildBannerCard(context, state),

            const SizedBox(height: 22),

            // 4. Dynamic Categories Row
            _buildCategoryRow(context, state),

            const SizedBox(height: 24),

            // 5. Dynamic Sections (Best Deals / Catalog Sections)
            if (state.sections.isNotEmpty)
              ...state.sections.map((section) => Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _buildDynamicSection(context, section),
                  ))
            else ...[
              // Fallback UI matching exact screenshot when loading/empty
              _buildBestDealsSection(context),
              const SizedBox(height: 24),
              _buildTrendingProductsSection(context),
            ],

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  /// Top location bar with notification bell
  Widget _buildHeader(BuildContext context, String addressText) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => context.push(RoutePaths.addressSelection),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFE6F4EE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Color(0xFF00875A),
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => context.push(RoutePaths.addressSelection),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Deliver to',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF00875A),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        addressText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF0F172A),
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        GestureDetector(
          onTap: () => context.push(RoutePaths.coupons),
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
                top: 4,
                right: 4,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Search Bar with Scanner Icon
  Widget _buildSearchBar(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(RoutePaths.search),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              color: Color(0xFF475569),
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Search for fruits, vegetables...',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => SmartScan.run(context, ref),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF00875A), width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Color(0xFF00875A),
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dark emerald hero banner card displaying home page banner
  Widget _buildBannerCard(BuildContext context, HomeState state) {
    final banners = state.banners;
    final currentBanner = banners.isNotEmpty ? banners.first : null;

    return GestureDetector(
      onTap: currentBanner != null
          ? () => _openBanner(context, currentBanner)
          : () => context.push(
                RoutePaths.productListing,
                extra: const ProductListingArgs(title: 'Fresh Groceries'),
              ),
      child: Container(
        width: double.infinity,
        height: 165,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF044E38),
              Color(0xFF036C4B),
              Color(0xFF02875D),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00875A).withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned(
                left: 18,
                top: 18,
                bottom: 18,
                right: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      currentBanner?.title.isNotEmpty == true
                          ? currentBanner!.title
                          : 'Fresh Groceries',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Up to 50% Off',
                      style: GoogleFonts.outfit(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currentBanner?.ctaText.isNotEmpty == true
                                ? currentBanner!.ctaText
                                : 'Shop Now',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF036C4B),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: Color(0xFF036C4B),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🌿', style: TextStyle(fontSize: 10)),
                      const SizedBox(width: 3),
                      Text(
                        'Live Fresh',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Right side home page banner image
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 160,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  child: currentBanner != null && currentBanner.imageUrl.isNotEmpty
                      ? AppNetworkImage(
                          url: currentBanner.imageUrl,
                          width: 160,
                          height: 165,
                          fit: BoxFit.cover,
                        )
                      : Image.asset(
                          'assets/images/banner_vegetables.png',
                          width: 160,
                          height: 165,
                          fit: BoxFit.cover,
                          alignment: Alignment.centerLeft,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.shopping_basket_rounded,
                            size: 80,
                            color: Colors.white24,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Categories circular icons list showing full circle icons
  Widget _buildCategoryRow(BuildContext context, HomeState state) {
    final colors = [
      const Color(0xFFFFF1F2),
      const Color(0xFFECFDF5),
      const Color(0xFFEFF6FF),
      const Color(0xFFFFF7ED),
      const Color(0xFFF0F9FF),
    ];

    final fallbackCategories = [
      ('Fruits', 'assets/images/cat_fruits.png', const Color(0xFFFFF1F2)),
      ('Vegetables', 'assets/images/cat_vegetables.png', const Color(0xFFECFDF5)),
      ('Dairy', 'assets/images/cat_dairy.png', const Color(0xFFEFF6FF)),
      ('Snacks', 'assets/images/cat_snacks.png', const Color(0xFFFFF7ED)),
      ('Beverages', 'assets/images/cat_beverages.png', const Color(0xFFF0F9FF)),
    ];

    final hasCategories = state.categories.isNotEmpty;
    final count = hasCategories ? state.categories.length : fallbackCategories.length;

    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final String name;
          final String imageUrl;
          final String? id;
          final Color bgColor = colors[index % colors.length];

          if (hasCategories) {
            final cat = state.categories[index];
            name = cat.name;
            imageUrl = cat.imageUrl;
            id = cat.id;
          } else {
            final fb = fallbackCategories[index];
            name = fb.$1;
            imageUrl = fb.$2;
            id = null;
          }

          return GestureDetector(
            onTap: () {
              if (id != null) {
                context.push(RoutePaths.subCategoryOf(id));
              } else {
                context.go(RoutePaths.categories);
              }
            },
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
                    child: imageUrl.startsWith('http')
                        ? AppNetworkImage(
                            url: imageUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            fallbackIcon: Icons.category_rounded,
                          )
                        : Image.asset(
                            imageUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                              Icons.category_rounded,
                              color: Color(0xFF00875A),
                              size: 28,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 64,
                  child: Text(
                    name,
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

  /// Dynamic Catalog Section (Renders backend HomeSection products)
  Widget _buildDynamicSection(BuildContext context, HomeSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              section.title,
              style: GoogleFonts.outfit(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            GestureDetector(
              onTap: () => context.push(
                RoutePaths.productListing,
                extra: ProductListingArgs(
                  title: section.title,
                  categoryId: section.categoryId,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'See All',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF00875A),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Color(0xFF00875A),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 225,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: section.products.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final product = section.products[index];
              return _buildDynamicProductCard(context, product);
            },
          ),
        ),
      ],
    );
  }

  /// Dynamic product card with cart integration
  Widget _buildDynamicProductCard(BuildContext context, Product product) {
    final strikePrice = product.strikePrice;
    final discountPercent = product.discountPercent;

    return GestureDetector(
      onTap: () => context.push(
        RoutePaths.productDetailsOf(product.id),
        extra: product,
      ),
      child: Container(
        width: 145,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 95,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: AppNetworkImage(
                      url: product.imageUrl,
                      fit: BoxFit.contain,
                      fallbackIcon: Icons.shopping_bag_outlined,
                    ),
                  ),
                ),
                if (discountPercent > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00875A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '-$discountPercent%',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13,
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
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                if (strikePrice != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '₹${strikePrice.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF94A3B8),
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ],
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                ref.read(cartProvider.notifier).add(product);
              },
              child: Container(
                height: 32,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF00875A),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Add +',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Best Deals section fallback
  Widget _buildBestDealsSection(BuildContext context) {
    final bestDeals = [
      (
        'Organic Bananas',
        '₹45',
        '₹56',
        '-20%',
        'assets/images/product_bananas.png',
      ),
      (
        'Fresh Milk',
        '₹60',
        '₹70',
        '-15%',
        'assets/images/product_milk.png',
      ),
      (
        'Brown Bread',
        '₹60',
        '₹70',
        '-10%',
        'assets/images/product_bread.png',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Best Deals',
              style: GoogleFonts.outfit(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            GestureDetector(
              onTap: () => context.push(
                RoutePaths.productListing,
                extra: const ProductListingArgs(title: 'Best Deals'),
              ),
              child: Row(
                children: [
                  Text(
                    'See All',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF00875A),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Color(0xFF00875A),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 225,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: bestDeals.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = bestDeals[index];
              return _buildProductCard(
                context: context,
                title: item.$1,
                price: item.$2,
                oldPrice: item.$3,
                discount: item.$4,
                assetPath: item.$5,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard({
    required BuildContext context,
    required String title,
    required String price,
    required String oldPrice,
    required String discount,
    required String assetPath,
  }) {
    return Container(
      width: 145,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 95,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Image.asset(
                    assetPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00875A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    discount,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                price,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                oldPrice,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF94A3B8),
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              context.push(
                RoutePaths.productListing,
                extra: ProductListingArgs(title: title),
              );
            },
            child: Container(
              height: 32,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF00875A),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                'Add +',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Trending Products section fallback
  Widget _buildTrendingProductsSection(BuildContext context) {
    final trending = [
      (
        'Organic Bananas',
        '₹45',
        'assets/images/product_bananas.png',
      ),
      (
        'Brown Bread',
        '₹60',
        'assets/images/product_bread.png',
      ),
      (
        'Fresh Milk',
        '₹70',
        'assets/images/product_milk.png',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trending Products',
          style: GoogleFonts.outfit(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: trending.map((item) {
            return Container(
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
                    child: Image.asset(
                      item.$3,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.shopping_bag_outlined,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$1,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.$2,
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
            );
          }).toList(),
        ),
      ],
    );
  }

  void _openBanner(BuildContext context, PromoBanner banner) {
    switch (banner.target) {
      case BannerTarget.offers:
        context.push(RoutePaths.coupons);
        break;
      case BannerTarget.category:
        if (banner.targetId.isNotEmpty) {
          context.push(RoutePaths.subCategoryOf(banner.targetId));
        } else {
          context.go(RoutePaths.categories);
        }
        break;
      case BannerTarget.restaurant:
        context.push(
          RoutePaths.productListing,
          extra: ProductListingArgs(
            title: banner.title,
            sellerId: banner.targetId,
          ),
        );
        break;
      case BannerTarget.products:
      case BannerTarget.none:
        context.push(
          RoutePaths.productListing,
          extra: ProductListingArgs(
            title: banner.title.isEmpty ? 'Featured Products' : banner.title,
          ),
        );
        break;
    }
  }
}
