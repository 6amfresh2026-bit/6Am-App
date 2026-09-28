import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:food_user_application/core/router/app_router.dart';
import 'package:food_user_application/core/services/fcm_service.dart';
import 'package:food_user_application/core/services/location_service.dart';
import 'package:food_user_application/core/services/new_order_overlay_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:food_user_application/core/services/referral_tracking_service.dart';
import 'package:food_user_application/core/theme/app_theme.dart';
import 'package:food_user_application/core/theme/theme_mode_provider.dart';
import 'package:food_user_application/features/orders/application/active_trip_visibility_controller.dart';
import 'package:food_user_application/features/orders/application/incoming_order_controller.dart';
import 'package:food_user_application/features/orders/application/orders_controller.dart';
import 'package:food_user_application/features/orders/application/orders_state.dart';
import 'package:food_user_application/features/orders/application/pending_customer_rating_controller.dart';
import 'package:food_user_application/features/orders/presentation/screens/active_trip_screen.dart';
import 'package:food_user_application/features/orders/presentation/screens/incoming_order_screen.dart';
import 'package:food_user_application/core/presentation/widgets/no_network_overlay.dart';
import 'package:food_user_application/core/services/network_controller.dart';
import 'package:food_user_application/features/orders/presentation/screens/rate_customer_screen.dart';
import 'package:food_user_application/core/constants/app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ProviderScope(child: QuickCommerceDeliveryApp()));
}

class QuickCommerceDeliveryApp extends ConsumerStatefulWidget {
  const QuickCommerceDeliveryApp({super.key});

  @override
  ConsumerState<QuickCommerceDeliveryApp> createState() => _QuickCommerceDeliveryAppState();
}

/// Bumped only if a future release needs to re-ask everyone.
const _permissionsAskedKey = 'permissions_requested_v1';

class _QuickCommerceDeliveryAppState extends ConsumerState<QuickCommerceDeliveryApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      ref.read(fcmServiceProvider).initialize();
      ReferralTrackingService.initialize();
      await _requestFirstLaunchPermissions();
      _consumeOverlayHandoff();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Tapping the overlay resumes an already-running app rather than starting
      // it, so the handoff has to be picked up here as well as at launch.
      _consumeOverlayHandoff();
      // Re-checks the full-screen-intent permission on every resume,
      // not just cold start — catches a rider who dismissed the Settings
      // prompt the first time or toggled it manually while the app was
      // backgrounded (see FcmService.ensureAndroidAlertPermissions).
      ref.read(fcmServiceProvider).ensureAndroidAlertPermissions();

      // Re-register the push token on every resume, for the same reason.
      //
      // Registration only happened at launch and login, so a save that failed
      // — or a token FCM rotated while the app was closed — left the rider
      // silently unreachable until the next relaunch. Five of six online riders
      // were in exactly that state: apps running, GPS fresh, no token on the
      // server, and no order offers reaching them.
      //
      // Idempotent server-side ($addToSet), so repeating it is free.
      unawaited(ref.read(fcmServiceProvider).registerToken());
    }
  }

  /// Asks for everything the app needs, once, on the first launch after install.
  ///
  /// These used to be requested at the point of use — location when the rider
  /// tapped Go Online, the overlay when the readiness screen was opened — which
  /// put a permission dialog in the middle of the one action that has to be
  /// instant, and left a rider who never opened that screen silently unable to
  /// receive an order card.
  ///
  /// The flag is written BEFORE the prompts rather than after: if the rider
  /// dismisses one and the app is killed, this must not re-prompt on every
  /// launch forever. Anything still missing is surfaced by the readiness
  /// screen, which is the place built for it.
  Future<void> _requestFirstLaunchPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_permissionsAskedKey) == true) return;
    await prefs.setBool(_permissionsAskedKey, true);

    // Runtime dialogs first — they are quick and can be answered in place.
    await ref.read(fcmServiceProvider).ensureAndroidAlertPermissions();
    await ref.read(locationServiceProvider).ensurePermissions();

    // "Display over other apps" last, deliberately: it cannot be granted by a
    // dialog, so it throws the rider out to a Settings screen. Doing it after
    // the in-place prompts means they answer everything else first.
    if (!await NewOrderOverlayBridge.hasPermission()) {
      await NewOrderOverlayBridge.requestPermission();
    }
  }

  /// Picks up whatever the native overlay left for us: the order the partner
  /// tapped, and any they rejected while the app was not running.
  Future<void> _consumeOverlayHandoff() async {
    final controller = ref.read(incomingOrderControllerProvider.notifier);
    unawaited(controller.flushOverlayRejections());

    final handoff = await NewOrderOverlayBridge.consumeLaunchOrder();
    if (handoff == null || !mounted) return;
    await controller.showById(handoff.orderId, autoAccept: handoff.autoAccept);
  }

  @override
  Widget build(BuildContext context) {
    final goRouter = ref.watch(goRouterProvider);

    final themeMode = ref.watch(themeModeProvider);

    return ScreenUtilInit(
      designSize: const Size(375, 812), // Standard design size
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: AppConstants.title,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          routerConfig: goRouter,
          builder: (context, routedChild) {
            final isDarkMode = Theme.of(context).brightness == Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
              child: Stack(
                children: [
                  if (routedChild != null) routedChild,
                Consumer(
                  builder: (context, ref, _) {
                    final ordersState = ref.watch(ordersControllerProvider);
                    final hasActiveOrder =
                        ordersState is OrdersLoaded &&
                        ordersState.currentOrder != null;
                    final showTrip = ref.watch(
                      activeTripVisibilityControllerProvider,
                    );
                    if (!hasActiveOrder || !showTrip) {
                      return const SizedBox.shrink();
                    }
                    return const ActiveTripScreen();
                  },
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final incomingOrder = ref.watch(
                      incomingOrderControllerProvider,
                    );
                    if (incomingOrder == null) return const SizedBox.shrink();
                    return IncomingOrderScreen(
                      key: ValueKey(incomingOrder.id),
                      order: incomingOrder,
                    );
                  },
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final pendingRating = ref.watch(
                      pendingCustomerRatingControllerProvider,
                    );
                    if (pendingRating == null) return const SizedBox.shrink();
                    return RateCustomerScreen(
                      key: ValueKey(pendingRating.id),
                      order: pendingRating,
                    );
                  },
                ),
                  Consumer(
                    builder: (context, ref, _) {
                      final isOnline = ref.watch(networkControllerProvider);
                      if (isOnline) return const SizedBox.shrink();
                      return const NoNetworkOverlay();
                    },
                  ),
                ],
              )
            );
          },
        );
      },
    );
  }
}
