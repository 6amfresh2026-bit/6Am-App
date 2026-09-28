import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_durations.dart';
import '../domain/model/address.dart';
import '../domain/model/category.dart';
import '../domain/model/order.dart';
import '../domain/model/product.dart';
import '../platform/location/location_service.dart';
import '../ui/screens/address/addresses_screen.dart';
import '../ui/screens/auth/login/login_screen.dart';
import '../ui/screens/auth/otp/otp_screen.dart';
import '../ui/screens/auth/register/register_screen.dart';
import '../ui/screens/brand/brand_listing_screen.dart';
import '../ui/screens/cart/cart_screen.dart';
import '../ui/screens/chat/chat_screen.dart';
import '../ui/screens/category/categories/categories_screen.dart';
import '../ui/screens/category/sub_category/sub_category_screen.dart';
import '../ui/screens/checkout/checkout_screen.dart';
import '../ui/screens/coupons/coupons_screen.dart';
import '../ui/screens/home/home_screen.dart';
import '../ui/screens/location/address_selection/address_selection_screen.dart';
import '../ui/screens/monthly_list/monthly_list_detail_screen.dart';
import '../ui/screens/monthly_list/monthly_lists_screen.dart';
import '../ui/screens/notifications/notifications_screen.dart';
import '../ui/screens/onboarding/onboarding_screen.dart';
import '../ui/screens/order/order_details/order_details_screen.dart';
import '../ui/screens/order/order_success/order_success_screen.dart';
import '../ui/screens/order/order_tracking/order_tracking_screen.dart';
import '../ui/screens/order/orders_list/orders_screen.dart';
import '../ui/screens/payment/payment_screen.dart';
import '../ui/screens/product/product_details/product_details_screen.dart';
import '../ui/screens/product/product_listing/product_listing_args.dart';
import '../ui/screens/product/product_listing/product_listing_screen.dart';
import '../ui/screens/profile/about/about_screen.dart';
import '../ui/screens/profile/edit_profile/edit_profile_screen.dart';
import '../ui/screens/profile/help/help_screen.dart';
import '../ui/screens/profile/privacy_policy/privacy_policy_screen.dart';
import '../ui/screens/profile/profile_home/profile_screen.dart';
import '../ui/screens/profile/settings/settings_screen.dart';
import '../ui/screens/profile/terms/terms_screen.dart';
import '../ui/screens/search/search_screen.dart';
import '../ui/screens/splash/splash_screen.dart';
import '../ui/screens/subscription/subscription_detail_screen.dart';
import '../ui/screens/subscription/subscription_screen.dart';
import '../ui/screens/subscription/subscriptions_screen.dart';
import '../ui/screens/wallet/wallet_screen.dart';
import '../ui/screens/wishlist/wishlist_screen.dart';
import '../ui/shell/app_shell.dart';
import 'route_paths.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// The app's route table.
///
/// Top-level tabs live in a [StatefulShellRoute] so each keeps its own
/// navigation stack and scroll position; everything else is pushed on the root
/// navigator so it covers the bottom bar.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: RoutePaths.splash,
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        name: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.onboarding,
        name: RouteNames.onboarding,
        pageBuilder: (context, state) =>
            _fadeThrough(state, const OnboardingScreen()),
      ),
      GoRoute(
        path: RoutePaths.login,
        name: RouteNames.login,
        pageBuilder: (context, state) => _fadeThrough(state, const LoginScreen()),
      ),
      GoRoute(
        path: RoutePaths.otp,
        name: RouteNames.otp,
        builder: (context, state) {
          final extra = state.extra as ({String phone, String? debugOtp})?;
          return OtpScreen(
            phone: extra?.phone ?? '',
            debugOtp: extra?.debugOtp,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.register,
        name: RouteNames.register,
        pageBuilder: (context, state) =>
            _fadeThrough(state, const RegisterScreen()),
      ),
      GoRoute(
        path: RoutePaths.addressSelection,
        name: RouteNames.addressSelection,
        pageBuilder: (context, state) {
          final extra = state.extra;
          return _slideUp(
            state,
            AddressSelectionScreen(
              existing: extra is Address ? extra : null,
              initialLocation: extra is DeviceLocation ? extra : null,
            ),
          );
        },
      ),

      // ── Tabs ──────────────────────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellKey,
            routes: [
              GoRoute(
                path: RoutePaths.home,
                name: RouteNames.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.categories,
                name: RouteNames.categories,
                builder: (context, state) =>
                    const CategoriesScreen(showAppBar: false),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.cart,
                name: RouteNames.cart,
                builder: (context, state) => const CartScreen(showAppBar: false),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.orders,
                name: RouteNames.orders,
                builder: (context, state) =>
                    const OrdersScreen(showAppBar: false),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.profile,
                name: RouteNames.profile,
                builder: (context, state) =>
                    const ProfileScreen(showAppBar: false),
              ),
            ],
          ),
        ],
      ),

      // ── Pushed over the shell ─────────────────────────────────────────────
      GoRoute(
        path: RoutePaths.search,
        name: RouteNames.search,
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) => _fadeThrough(
          state,
          SearchScreen(
            autoStartVoice: state.uri.queryParameters['voice'] == '1',
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.subCategory,
        name: RouteNames.subCategory,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => SubCategoryScreen(
          categoryId: state.pathParameters['id']!,
          category: state.extra is Category ? state.extra as Category : null,
        ),
      ),
      GoRoute(
        path: RoutePaths.brands,
        name: RouteNames.brands,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const BrandListingScreen(),
      ),
      GoRoute(
        path: RoutePaths.productListing,
        name: RouteNames.productListing,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => ProductListingScreen(
          args: state.extra is ProductListingArgs
              ? state.extra as ProductListingArgs
              : const ProductListingArgs(title: 'All products'),
        ),
      ),
      GoRoute(
        path: RoutePaths.productDetails,
        name: RouteNames.productDetails,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => ProductDetailsScreen(
          productId: state.pathParameters['id']!,
          product: state.extra is Product ? state.extra as Product : null,
        ),
      ),
      GoRoute(
        path: RoutePaths.wishlist,
        name: RouteNames.wishlist,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const WishlistScreen(),
      ),
      GoRoute(
        path: RoutePaths.wallet,
        name: RouteNames.wallet,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: RoutePaths.checkout,
        name: RouteNames.checkout,
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) => _slideUp(state, const CheckoutScreen()),
      ),
      GoRoute(
        path: RoutePaths.coupons,
        name: RouteNames.coupons,
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) => _slideUp(state, const CouponsScreen()),
      ),
      GoRoute(
        path: RoutePaths.payment,
        name: RouteNames.payment,
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) => _slideUp(
          state,
          PaymentScreen(placedOrder: state.extra! as PlacedOrder),
        ),
      ),
      GoRoute(
        path: RoutePaths.addresses,
        name: RouteNames.addresses,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const AddressesScreen(),
      ),
      GoRoute(
        path: RoutePaths.notifications,
        name: RouteNames.notifications,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: RoutePaths.orderSuccess,
        name: RouteNames.orderSuccess,
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) =>
            _fadeThrough(state, OrderSuccessScreen(order: state.extra! as Order)),
      ),
      GoRoute(
        path: RoutePaths.orderTracking,
        name: RouteNames.orderTracking,
        parentNavigatorKey: _rootKey,
        builder: (context, state) =>
            OrderTrackingScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RoutePaths.orderChat,
        name: RouteNames.orderChat,
        parentNavigatorKey: _rootKey,
        builder: (context, state) {
          final extra = state.extra is ChatArgs ? state.extra as ChatArgs : null;
          return ChatScreen(
            orderId: state.pathParameters['id']!,
            riderName: extra?.riderName ?? 'Delivery partner',
            riderId: extra?.riderId ?? '',
          );
        },
      ),
      GoRoute(
        path: RoutePaths.orderDetails,
        name: RouteNames.orderDetails,
        parentNavigatorKey: _rootKey,
        builder: (context, state) =>
            OrderDetailsScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RoutePaths.monthlyLists,
        name: RouteNames.monthlyLists,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const MonthlyListsScreen(),
      ),
      GoRoute(
        path: RoutePaths.monthlyListDetails,
        name: RouteNames.monthlyListDetails,
        parentNavigatorKey: _rootKey,
        builder: (context, state) =>
            MonthlyListDetailScreen(listId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RoutePaths.subscriptions,
        name: RouteNames.subscriptions,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const SubscriptionsScreen(),
      ),
      GoRoute(
        path: RoutePaths.subscriptionCreate,
        name: RouteNames.subscriptionCreate,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => SubscriptionScreen(
          product: state.extra is Product ? state.extra as Product : null,
        ),
      ),
      GoRoute(
        path: RoutePaths.subscriptionDetails,
        name: RouteNames.subscriptionDetails,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => SubscriptionDetailScreen(
          subscriptionId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: RoutePaths.editProfile,
        name: RouteNames.editProfile,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.help,
        name: RouteNames.help,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const HelpScreen(),
      ),
      GoRoute(
        path: RoutePaths.settings,
        name: RouteNames.settings,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.privacyPolicy,
        name: RouteNames.privacyPolicy,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: RoutePaths.terms,
        name: RouteNames.terms,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const TermsScreen(),
      ),
      GoRoute(
        path: RoutePaths.about,
        name: RouteNames.about,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const AboutScreen(),
      ),
    ],
    errorBuilder: (context, state) => _RouteNotFound(location: state.uri.path),
  );
});

/// Fade-through: used between top-level contexts that are not a stack push.
CustomTransitionPage<void> _fadeThrough(GoRouterState state, Widget child) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: AppDurations.medium,
      transitionsBuilder: (context, animation, secondary, child) => FadeTransition(
        opacity: CurveTween(curve: Curves.easeOut).animate(animation),
        child: ScaleTransition(
          scale: Tween(begin: 0.98, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut),
          ),
          child: child,
        ),
      ),
    );

/// Slide-up: modal-feeling routes such as checkout, coupons and payment.
CustomTransitionPage<void> _slideUp(GoRouterState state, Widget child) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: AppDurations.medium,
      transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: FadeTransition(opacity: animation, child: child),
      ),
    );

class _RouteNotFound extends StatelessWidget {
  const _RouteNotFound({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_rounded, size: 44),
              const SizedBox(height: 16),
              Text(
                'We could not find "$location"',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(RoutePaths.home),
                child: const Text('Go home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
