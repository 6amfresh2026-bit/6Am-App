import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:food_user_application/core/error/result.dart';
import 'package:food_user_application/features/notifications/data/notifications_repository.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:food_user_application/core/constants/map_styles.dart';
import 'package:food_user_application/core/constants/app_constants.dart';
import 'package:food_user_application/core/utils/map_launcher.dart';
import 'package:food_user_application/core/utils/polyline_decoder.dart';
import 'package:food_user_application/core/services/device_readiness_service.dart';
import 'package:food_user_application/core/services/location_service.dart';
import 'package:food_user_application/features/profile/presentation/screens/delivery_readiness_screen.dart';
import 'package:food_user_application/core/services/haptic_service.dart';
import 'package:food_user_application/core/services/sound_service.dart';
import 'package:food_user_application/features/auth/application/auth_controller.dart';
import 'package:food_user_application/features/auth/application/auth_state.dart';
import 'package:food_user_application/features/orders/presentation/widgets/otp_bottom_sheet.dart';
import 'package:food_user_application/features/orders/application/orders_controller.dart';
import 'package:food_user_application/features/orders/application/order_removed_notice_controller.dart';
import 'package:food_user_application/features/orders/application/orders_state.dart';
import 'package:food_user_application/features/orders/data/models/delivery_order.dart';
import 'package:food_user_application/features/orders/data/orders_repository.dart';
import 'package:food_user_application/features/orders/presentation/widgets/collect_payment_sheet.dart';
import 'package:food_user_application/features/orders/application/active_trip_visibility_controller.dart';
import 'package:food_user_application/features/profile/application/availability_controller.dart';
import 'package:food_user_application/features/main/presentation/screens/main_screen.dart';
import 'package:food_user_application/features/wallet/data/wallet_repository.dart';
import 'package:food_user_application/core/services/fcm_service.dart';
import 'package:food_user_application/features/refer_earn/application/referral_controller.dart';
import 'package:food_user_application/features/chat/presentation/screens/chat_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:food_user_application/core/theme/app_colors.dart';
import 'package:food_user_application/features/support/presentation/widgets/emergency_help_sheet.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  bool _isCurrentOrderVisible = true;
  bool _showReferEarn = true;
  bool _isActionLoading = false;

  Map<String, dynamic>? _earningsSummary;
  bool _earningsLoading = true;

  static const Color _onlineGreen = AppColors.online;

  BitmapDescriptor? _bikeMarkerIcon;
  GoogleMapController? _mapController;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSub;

  List<LatLng> _routePoints = [];
  LatLng? _routeDestination;
  String? _routeKey;
  Timer? _routeRefreshTimer;
  Timer? _pulseTimer;
  double _pulsePhase = 0.0;
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();

    _loadEarnings();
    _loadMarkerIcon();
    _initMapPosition();
    _loadUnreadCount();
    _listenForFcmNotifications();
    _positionSub = ref.read(locationServiceProvider).positionStream.listen((pos) {
      if (mounted) setState(() => _currentPosition = pos);
    });
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() => _pulsePhase = (_pulsePhase + 0.05) % 1.0);
    });
  }

  /// Offered when going online with something outstanding that will cost the
  /// rider orders.
  ///
  /// Self-limiting rather than gated on a "seen" flag: the checks report their
  /// real state, so once they are fixed this stops appearing on its own. Autostart
  /// is excluded from the blocking set precisely because no ROM lets us read it
  /// back — including it would make this prompt permanent and train riders to
  /// dismiss it without reading.
  Future<void> _promptDeviceReadiness() async {
    if (!Platform.isAndroid) return;
    if (!await DeviceReadinessService.hasBlockingIssues()) return;
    if (!mounted) return;

    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('You may miss orders'),
        content: const Text(
          'Your phone is set to stop this app running in the background. '
          'Orders can stop reaching you without any warning.\n\n'
          'It takes about a minute to fix.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Fix now'),
          ),
        ],
      ),
    );

    if (open == true && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DeliveryReadinessScreen()),
      );
    }
  }

  Future<void> _loadUnreadCount() async {
    final result = await ref.read(notificationsRepositoryProvider).getInbox(limit: 1);
    if (!mounted) return;
    result.when(
      success: (data) => setState(() {
        _unreadNotificationCount = (data['unreadCount'] as num?)?.toInt() ?? 0;
      }),
      failure: (_) {},
    );
  }

  void _listenForFcmNotifications() {
    final fcmService = ref.read(fcmServiceProvider);
    fcmService.onNotificationReceived.listen((data) {
      _loadUnreadCount();
      if (data['type'] == 'referral_bonus') {
        _showReferralBonusCelebration(data['amount']?.toString() ?? '');
        ref.read(referralControllerProvider.notifier).refreshStats();
        _loadEarnings(); // Refresh wallet/earnings
      }
    });
  }

  void _showReferralBonusCelebration(String amount) {
    if (!mounted) return;
    
    // Play sound and haptic
    SoundService.playEffect('refferticketcomeout.mp3');
    HapticService.heavy();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        title: Column(
          children: [
            Icon(Icons.celebration, color: AppColors.rating, size: 48.sp),
            SizedBox(height: 12.h),
            Text(
              'Referral Bonus!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24.sp),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Text(
          'You just earned ₹$amount for a successful referral!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16.sp, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Awesome!', style: TextStyle(color: AppColors.success)),
          ),
        ],
      ),
    );
  }

  Future<Uint8List> _getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }

  Future<void> _loadMarkerIcon() async {
    try {
      // Kept in step with ActiveTripScreen — it is the same rider on the same
      // map, so the two must not be different sizes.
      final Uint8List markerIcon = await _getBytesFromAsset('assets/image/bike.png', 60);
      _bikeMarkerIcon = BitmapDescriptor.bytes(markerIcon);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Failed to load map marker: $e');
    }
  }

  /// Seeds the map preview with a fix even when the rider is offline (and
  /// therefore [LocationService.startTracking] hasn't run yet), so the
  /// preview never gets stuck on the placeholder icon.
  Future<void> _initMapPosition() async {
    final locationService = ref.read(locationServiceProvider);
    if (locationService.lastPosition != null) {
      if (mounted) setState(() => _currentPosition = locationService.lastPosition);
      return;
    }
    if (locationService.isTracking) return;

    final permission = await Geolocator.checkPermission();
    final isGranted = permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
    if (!isGranted || !mounted) return;

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      locationService.lastPosition = pos;
      if (mounted) setState(() => _currentPosition = pos);
    } catch (_) {
      // No fix available yet — the placeholder stays until tracking starts.
    }
  }

  @override
  void dispose() {
    _routeRefreshTimer?.cancel();
    _positionSub?.cancel();
    _pulseTimer?.cancel();
    super.dispose();
  }

  void _maybeFetchRoute(DeliveryOrder order) {
    final navigateToStore = order.currentPhase == 'en_route_to_pickup' ||
        order.currentPhase == 'at_pickup';
    final target = navigateToStore ? 'restaurant' : 'customer';
    final key = '${order.id}::$target';
    if (key == _routeKey) return;
    _routeKey = key;
    _fetchRoute(order, target);

    _routeRefreshTimer?.cancel();
    _routeRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final ordersState = ref.read(ordersControllerProvider);
      if (ordersState is OrdersLoaded && ordersState.hasActiveOrder) {
        _fetchRoute(ordersState.currentOrder!, target);
      }
    });
  }

  Future<void> _fetchRoute(DeliveryOrder order, String target) async {
    final pos = ref.read(locationServiceProvider).lastPosition;
    if (pos == null) return;
    final result = await ref.read(ordersRepositoryProvider).getRoute(
          order.id,
          lat: pos.latitude,
          lng: pos.longitude,
          target: target,
        );
    if (!mounted) return;
    result.when(
      success: (data) {
        final encoded = data['polyline'] as String?;
        final points = (encoded != null && encoded.isNotEmpty)
            ? decodePolyline(encoded)
            : <LatLng>[];
        final destLoc = target == 'restaurant'
            ? order.store.location
            : order.deliveryAddress.location;
        final destination = destLoc != null
            ? LatLng(destLoc.lat, destLoc.lng)
            : (points.isNotEmpty ? points.last : null);
        setState(() {
          _routePoints = points;
          _routeDestination = destination;
        });
        if (destination != null && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(
              _boundsFor(LatLng(pos.latitude, pos.longitude), destination),
              80,
            ),
          );
        }
      },
      failure: (_) {},
    );
  }

  LatLngBounds _boundsFor(LatLng a, LatLng b) {
    return LatLngBounds(
      southwest: LatLng(
        a.latitude < b.latitude ? a.latitude : b.latitude,
        a.longitude < b.longitude ? a.longitude : b.longitude,
      ),
      northeast: LatLng(
        a.latitude > b.latitude ? a.latitude : b.latitude,
        a.longitude > b.longitude ? a.longitude : b.longitude,
      ),
    );
  }

  void _clearRoute() {
    _routeRefreshTimer?.cancel();
    _routeRefreshTimer = null;
    _routeKey = null;
    if (_routePoints.isNotEmpty || _routeDestination != null) {
      setState(() {
        _routePoints = [];
        _routeDestination = null;
      });
    }
  }

  Future<void> _loadEarnings() async {
    final result = await ref.read(walletRepositoryProvider).getEarnings(period: 'today');
    if (!mounted) return;
    result.when(
      success: (data) => setState(() {
        _earningsSummary = data['summary'] as Map<String, dynamic>?;
        _earningsLoading = false;
      }),
      failure: (_) => setState(() => _earningsLoading = false),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runAction(Future<Result<DeliveryOrder, AppError>> Function() call) async {
    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);
    final result = await call();
    if (mounted) setState(() => _isActionLoading = false);
    result.when(success: (_) {}, failure: (error) => _showSnack(error.message));
  }

  ({String label, IconData icon, Future<void> Function() action})? _actionFor(DeliveryOrder order) {
    final controller = ref.read(ordersControllerProvider.notifier);
    switch (order.currentPhase) {
      case 'en_route_to_pickup':
        return (
          label: 'Reached Pickup',
          icon: Icons.storefront_outlined,
          action: () => _runAction(() => controller.reachedPickup(order.id)),
        );
      case 'at_pickup':
        return (
          label: 'Confirm Pickup',
          icon: Icons.check_circle_outline,
          action: () => _runAction(() => controller.confirmPickup(order.id)),
        );
      case 'en_route_to_delivery':
        return (
          label: 'Reached Drop',
          icon: Icons.flag_outlined,
          action: () => _runAction(() => controller.reachedDrop(order.id)),
        );
      case 'at_drop':
        if (order.dropOtpRequired && !order.dropOtpVerified) {
          return (
            label: 'Verify OTP',
            icon: Icons.password_outlined,
            action: () => _promptDropOtp(order),
          );
        }
        if (!order.isPaid) {
          return (
            label: 'Collect Payment',
            icon: Icons.payments_outlined,
            action: () => _showCollectPaymentSheet(order),
          );
        }
        return (
          label: 'Complete Delivery',
          icon: Icons.done_all_rounded,
          action: () => _runAction(() => controller.completeOrder(order.id)),
        );
      default:
        return null;
    }
  }

  Future<void> _promptDropOtp(DeliveryOrder order) async {
    final controller = ref.read(ordersControllerProvider.notifier);
    final otp = await showOtpBottomSheet(context, customerName: order.customerName);
    if (otp == null || otp.length != 4) return;
    final result = await controller.verifyDropOtp(order.id, otp);
    result.when(success: (_) {}, failure: (error) => _showSnack(error.message));
  }

  Future<void> _showCollectPaymentSheet(DeliveryOrder order) async {
    final collected = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CollectPaymentSheet(order: order),
    );
    if (collected == true) {
      await _runAction(() => ref.read(ordersControllerProvider.notifier).completeOrder(order.id));
    }
  }

  Future<void> _callCustomer(DeliveryOrder order) async {
    if (order.customerPhone.isEmpty) return;
    await _dial(order.customerPhone);
  }

  Future<void> _dial(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Refetched rather than cached: an order completed while this screen sat in
    // the IndexedStack must show up in Today's Earning without a manual pull.
    ref.listen<int>(earningsRefreshProvider, (_, _) => _loadEarnings());
    // An order can be taken away for three different reasons — the accept
    // window lapsing, the customer cancelling, the shop never answering. Say
    // which, rather than letting it vanish off the list unexplained.
    ref.listen<String?>(orderRemovedNoticeProvider, (_, reason) {
      if (reason == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reason),
          duration: const Duration(seconds: 6),
        ),
      );
      ref.read(orderRemovedNoticeProvider.notifier).clear();
    });
    ref.listen<int>(mainTabIndexProvider, (previous, next) {
      if (next == 0 && previous != 0) _loadEarnings();
    });

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = AppColors.of(context).textPrimary;
    final subTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    final isOnline = ref.watch(availabilityControllerProvider);
    final ordersState = ref.watch(ordersControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final partnerName = authState is AuthAuthenticated ? authState.user.name : '';

    ref.listen<OrdersState>(ordersControllerProvider, (previous, next) {
      if (previous is OrdersLoaded && next is OrdersLoaded) {
        if (previous.hasActiveOrder && !next.hasActiveOrder) {
          // Order was completed or cancelled
          _loadEarnings();
          _clearRoute();
        } else if (previous.hasActiveOrder && next.hasActiveOrder &&
                   previous.currentOrder!.currentPhase != next.currentOrder!.currentPhase &&
                   next.currentOrder!.currentPhase == 'delivered') {
          // Order was delivered
          _loadEarnings();
        }
      }
      if (next is OrdersLoaded && next.hasActiveOrder) {
        _maybeFetchRoute(next.currentOrder!);
      } else if (next is OrdersLoaded) {
        _clearRoute();
      }
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: _buildMapPreview(isDarkMode, isOnline),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xE6161925) : Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32.r),
                  bottomRight: Radius.circular(32.r),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(textColor, subTextColor, partnerName),
                      SizedBox(height: 20.h),
                      _buildOnlineToggle(isOnline),
                      SizedBox(height: 16.h),
                      _buildEarningsAndOrdersRow(theme),
                      if (isOnline) ...[
                        if (_isCurrentOrderVisible && ordersState is OrdersLoaded && ordersState.hasActiveOrder) ...[
                          SizedBox(height: 24.h),
                          ..._buildOrdersSection(theme, isDarkMode, textColor, subTextColor, ordersState),
                        ]
                      ] else ...[
                        SizedBox(height: 24.h),
                        _buildOfflinePrompt(theme, isDarkMode, textColor, subTextColor),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_showReferEarn) _buildReferEarnFab(),
        ],
      ),
    );
  }

  List<Widget> _buildOrdersSection(
    ThemeData theme,
    bool isDarkMode,
    Color textColor,
    Color? subTextColor,
    OrdersState ordersState,
  ) {
    if (ordersState is OrdersLoading || ordersState is OrdersInitial) {
      return [
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24.h),
            child: CircularProgressIndicator(color: theme.primaryColor),
          ),
        ),
      ];
    }
    if (ordersState is OrdersError) {
      return [_buildOrdersErrorCard(theme, textColor, ordersState.message)];
    }
    if (ordersState is OrdersLoaded) {
      final order = ordersState.currentOrder;
      if (order != null) {
        return [
          _buildCurrentOrderHeader(textColor, order),
          SizedBox(height: 12.h),
          _buildCurrentOrderCard(theme, isDarkMode, textColor, subTextColor, order),
        ];
      }
      return const [];
    }
    return const [];
  }

  Widget _buildOrdersErrorCard(ThemeData theme, Color textColor, String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.error, size: 28.sp),
          SizedBox(height: 10.h),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: textColor, fontSize: 13.sp)),
          SizedBox(height: 12.h),
          TextButton(
            onPressed: () => ref.read(ordersControllerProvider.notifier).refreshAll(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color textColor, Color? subTextColor, String partnerName) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning,' : (hour < 17 ? 'Good Afternoon,' : 'Good Evening,');
    final displayName = partnerName.isNotEmpty ? partnerName : 'Partner';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(fontSize: 13.sp, color: subTextColor),
              ),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text('👋', style: TextStyle(fontSize: 18.sp)),
                ],
              ),
            ],
          ),
        ),
        _buildHeaderIcon(Icons.report_problem_outlined, () => showEmergencyHelpSheet(context, ref)),
        _buildHeaderIcon(Icons.assignment_ind_outlined, () => context.push('/driver-id-card')),
        _buildHeaderIcon(
          Icons.notifications_none_rounded,
          () => context.push('/notifications').then((_) => _loadUnreadCount()),
          _unreadNotificationCount,
        ),
        // _buildHeaderIcon(Icons.headset_mic_outlined, () {
        //    // Do nothing for now or dial support if known
        // }
        // ),
      ],
    );
  }

  Widget _buildHeaderIcon(IconData icon, VoidCallback onTap, [int unreadCount = 0]) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(left: 8.w),
        width: 44.r,
        height: 44.r,
        decoration: BoxDecoration( 
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: Colors.black, size: 22.sp),
            if (unreadCount > 0)
              Positioned(
                top: 8.h,
                right: 8.w,
                child: Container(
                  padding: EdgeInsets.all(4.r),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8.sp,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineToggle(bool isOnline) {
    return GestureDetector(
      onTap: () async {
        HapticService.light();
        final result = await ref.read(availabilityControllerProvider.notifier).toggle();
        result.when(
          success: (_) {
            if (ref.read(availabilityControllerProvider)) {
              _promptDeviceReadiness();
            }
          },
          failure: (error) => _showSnack(error.message),
        );
      },
      child: Row(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 52.h,
              padding: EdgeInsets.symmetric(horizontal: 6.w),
              decoration: BoxDecoration(
                color: isOnline ? _onlineGreen : Colors.grey[500],
                borderRadius: BorderRadius.circular(26.r),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 250),
                        alignment: isOnline ? Alignment.centerLeft : Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isOnline) ...[
                              Container(
                                width: 6.r,
                                height: 6.r,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 8.w),
                            ],
                            Text(
                              isOnline ? 'ONLINE' : 'OFFLINE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14.sp,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 250),
                    alignment: isOnline ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 40.r,
                      height: 40.r,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Icon(
                        Icons.bolt_rounded,
                        color: isOnline ? _onlineGreen : Colors.grey[500],
                        size: 22.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 10.w),
          GestureDetector(
            onTap: () {
              HapticService.light();
              setState(() => _isCurrentOrderVisible = !_isCurrentOrderVisible);
            },
            child: Container(
              width: 52.h,
              height: 52.h,
              decoration: const BoxDecoration(color: AppColors.lightNeutralDark, shape: BoxShape.circle),
              child: AnimatedRotation(
                turns: _isCurrentOrderVisible ? 0 : 0.5,
                duration: const Duration(milliseconds: 300),
                child: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsAndOrdersRow(ThemeData theme) {
    final totalEarnings = (_earningsSummary?['totalEarnings'] as num?)?.toDouble() ?? 0;
    final totalOrders = (_earningsSummary?['totalOrders'] as num?)?.toInt() ?? 0;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F6EF),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(6.r),
                  decoration: const BoxDecoration(color: Color(0xFFC8E6D9), shape: BoxShape.circle),
                  child: Icon(Icons.account_balance_wallet_rounded, color: AppColors.success, size: 18.sp),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Today's Earning", style: TextStyle(color: Colors.grey[700], fontSize: 10.sp, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4.h),
                      _earningsLoading 
                          ? SizedBox(height: 20.h, width: 20.h, child: const CircularProgressIndicator(strokeWidth: 2))
                          : Text('₹${totalEarnings.toStringAsFixed(2)}', style: TextStyle(color: Colors.black, fontSize: 16.sp, fontWeight: FontWeight.w900)),
                      //SizedBox(height: 4.h),
                      // Row(
                      //   children: [
                      //     Icon(Icons.arrow_drop_up_rounded, color: AppColors.success, size: 14.sp),
                      //     Text('12%', style: TextStyle(color: AppColors.success, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                      //   ],
                      // ),
                    //  Text('vs Yesterday', style: TextStyle(color: Colors.grey[500], fontSize: 9.sp)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: AppColors.pendingBg,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(6.r),
                  decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                  child: Icon(Icons.shopping_bag_rounded, color: AppColors.warning, size: 18.sp),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Today's Orders", style: TextStyle(color: Colors.grey[700], fontSize: 10.sp, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4.h),
                      _earningsLoading 
                          ? SizedBox(height: 20.h, width: 20.h, child: const CircularProgressIndicator(strokeWidth: 2))
                          : Text('$totalOrders', style: TextStyle(color: Colors.black, fontSize: 16.sp, fontWeight: FontWeight.w900)),
                      //SizedBox(height: 4.h),
                      // Row(
                      //   children: [
                      //     Icon(Icons.arrow_drop_up_rounded, color: AppColors.warning, size: 14.sp),
                      //     Text('3', style: TextStyle(color: AppColors.warning, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                      //   ],
                      // ),
                      // Text('vs Yesterday', style: TextStyle(color: Colors.grey[500], fontSize: 9.sp)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReferEarnFab() {
    return Positioned(
      right: -10.w,
      bottom: 110.h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 35.r),
            child: GestureDetector(
              onTap: () {
                HapticService.light();
                context.push('/refer-earn');
              },
              child: Image.asset('assets/image/refer.png', width: 90.r, height: 90.r),
            ),
          ),
          Positioned(
            right: 23,
            top: 5.r,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticService.light();
                setState(() => _showReferEarn = false);
                Future.delayed(const Duration(seconds: 30), () {
                  if (mounted) {
                    setState(() => _showReferEarn = true);
                  }
                });
              },
              child: Container(
                padding: EdgeInsets.all(4.r),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: Icon(Icons.close, color: Colors.white, size: 14.sp),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentOrderHeader(Color textColor, DeliveryOrder order) {
    final distanceLabel =
        order.tripDistanceKm != null ? '${order.tripDistanceKm!.toStringAsFixed(1)} km away' : '';
    return Row(
      children: [
        Text(
          'Current Order',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: textColor),
        ),
        const Spacer(),
        if (distanceLabel.isNotEmpty) ...[
          Icon(Icons.place_outlined, size: 14.sp, color: Colors.grey[500]),
          SizedBox(width: 4.w),
          Text(distanceLabel, style: TextStyle(fontSize: 12.sp, color: Colors.grey[500])),
        ],
      ],
    );
  }

  Widget _buildCurrentOrderCard(
    ThemeData theme,
    bool isDarkMode,
    Color textColor,
    Color? subTextColor,
    DeliveryOrder order,
  ) {
    final action = _actionFor(order);
    final paymentLabel = order.isCashOnDelivery
        ? '₹${order.total.toStringAsFixed(0)} COD'
        : '₹${order.total.toStringAsFixed(0)} Paid';

    final bool showNavigate = order.currentPhase == 'en_route_to_pickup' || 
                              order.currentPhase == 'at_pickup' || 
                              order.currentPhase == 'en_route_to_delivery' || 
                              order.currentPhase == 'at_drop';

    final bool navigateToStore = order.currentPhase == 'en_route_to_pickup' || 
                                      order.currentPhase == 'at_pickup';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => ref.read(activeTripVisibilityControllerProvider.notifier).show(),
      child: Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Icon(Icons.trip_origin, size: 14.sp, color: theme.primaryColor),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 4.h),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            4,
                            (i) => Container(width: 2, height: 4.h, color: Colors.grey[350]),
                          ),
                        ),
                      ),
                    ),
                    Icon(Icons.location_on, size: 16.sp, color: _onlineGreen),
                  ],
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.store.name,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp, color: textColor),
                      ),
                      Text(
                        order.store.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.sp, color: subTextColor),
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        order.customerName,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp, color: textColor),
                      ),
                      Text(
                        order.deliveryAddress.fullAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.sp, color: subTextColor),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    paymentLabel,
                    style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.w800, fontSize: 11.sp),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          _buildLocationSharingStatus(),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isActionLoading
                      ? null
                      : () {
                          HapticService.light();
                          action?.action();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: AppColors.onPrimary,
                    disabledBackgroundColor: theme.primaryColor.withValues(alpha: 0.5),
                    elevation: 0,
                    minimumSize: Size(double.infinity, 48.h),
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                  ),
                  child: _isActionLoading
                      ? SizedBox(
                          width: 20.r,
                          height: 20.r,
                          child: CircularProgressIndicator(color: AppColors.onPrimary, strokeWidth: 2.5),
                        )
                      : Text(
                          action?.label ?? 'Processing…',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.sp, color: AppColors.onPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
              if (showNavigate) ...[
                SizedBox(width: 8.w),
                GestureDetector(
                  onTap: () {
                    if (navigateToStore && order.store.location != null) {
                      MapLauncher.launchGoogleMaps(order.store.location!.lat, order.store.location!.lng);
                    } else if (!navigateToStore && order.deliveryAddress.location != null) {
                      MapLauncher.launchGoogleMaps(order.deliveryAddress.location!.lat, order.deliveryAddress.location!.lng);
                    } else {
                      _showSnack('Location not available');
                    }
                  },
                  child: Container(
                    height: 48.h,
                    width: 48.h,
                    decoration: BoxDecoration(
                      color: AppColors.lightNeutralDark,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Icon(Icons.navigation_rounded, color: Colors.white, size: 18.sp),
                  ),
                ),
              ],
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: () => _callCustomer(order),
                child: Container(
                  height: 48.h,
                  width: 48.h,
                  decoration: BoxDecoration(
                    color: AppColors.lightNeutralDark,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Icon(Icons.call_rounded, color: Colors.white, size: 18.sp),
                ),
              ),
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: () {
                  HapticService.light();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(order: order)));
                },
                child: Container(
                  height: 48.h,
                  width: 48.h,
                  decoration: BoxDecoration(
                    color: AppColors.lightNeutralDark,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18.sp),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildLocationSharingStatus() {
    final isOnline = ref.watch(availabilityControllerProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8.r,
          height: 8.r,
          decoration: BoxDecoration(
            color: isOnline ? _onlineGreen : Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 6.w),
        Text(
          isOnline ? 'Sharing live location' : 'Location sharing paused',
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: isOnline ? _onlineGreen : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildOfflinePrompt(
    ThemeData theme,
    bool isDarkMode,
    Color textColor,
    Color? subTextColor,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        children: [
          Icon(Icons.pause_circle_outline_rounded, color: Colors.grey[400], size: 32.sp),
          SizedBox(height: 12.h),
          Text(
            "You're offline",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp, color: textColor),
          ),
          SizedBox(height: 4.h),
          Text(
            'Go online to start receiving delivery requests',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.sp, color: subTextColor),
          ),
        ],
      ),
    );
  }

  /// Builds the background map.
  /// 
  /// When OFFLINE — shows a cheap Static Maps API PNG so we don't burn
  /// a Dynamic Map load just to display a grey backdrop.
  /// When ONLINE — shows the live, interactive GoogleMap for GPS tracking.
  Widget _buildMapPreview(bool isDarkMode, bool isOnline) {
    final pos = _currentPosition;

    // --- OFFLINE: Static image (costs ~$2/1000 vs $7/1000 for Dynamic map) ---
    if (!isOnline) {
      if (pos == null) {
        // No GPS yet — just show the muted grey placeholder
        return Container(
          color: isDarkMode ? AppColors.mapPlaceholderDark : AppColors.mapPlaceholderLight,
          child: Center(
            child: Icon(
              Icons.two_wheeler_rounded,
              size: 36,
              color: isDarkMode ? Colors.white38 : Colors.black38,
            ),
          ),
        );
      }
      // Use the Static Maps API — a simple image, no SDK map load
      final staticUrl = Uri(
        scheme: 'https',
        host: 'maps.googleapis.com',
        path: '/maps/api/staticmap',
        queryParameters: {
          'center': '${pos.latitude},${pos.longitude}',
          'zoom': '15',
          'size': '640x480',
          'scale': '2', // Retina quality
          'style': [
            'element:geometry|color:0xf5f5f5',
            'element:labels.icon|visibility:off',
            'feature:poi|visibility:off',
            'feature:transit|visibility:off',
            'feature:road|element:geometry|color:0xffffff',
            'feature:water|element:geometry|color:0xc9c9c9',
          ],
          'markers': 'color:blue|${pos.latitude},${pos.longitude}',
          'key': AppConstants.mapKey,
        },
      ).toString();

      return Image.network(
        staticUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => Container(
          color: isDarkMode ? AppColors.mapPlaceholderDark : AppColors.mapPlaceholderLight,
        ),
      );
    }

    // --- ONLINE: Full interactive GoogleMap for live GPS tracking ---
    return SizedBox.expand(
      child: Stack(
        children: [
            Builder(
              builder: (context) {
                final pos = _currentPosition;
                if (pos == null) {
                  return Container(
                    color: isDarkMode ? AppColors.mapPlaceholderDark : AppColors.mapPlaceholderLight,
                    child: Center(
                      child: Icon(
                        Icons.two_wheeler_rounded,
                        size: 36.sp,
                        color: isDarkMode ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  );
                }
                final authState = ref.read(authControllerProvider);
                final bool isBike = authState is AuthAuthenticated &&
                                    (authState.user.vehicleType?.toLowerCase() == 'bike' ||
                                     authState.user.vehicleType?.toLowerCase() == 'two_wheeler');
                final bool useCustomMarker = isBike && _bikeMarkerIcon != null;

                return GoogleMap(
                  onMapCreated: (controller) => _mapController = controller,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(pos.latitude, pos.longitude),
                    zoom: 16,
                  ),
                  markers: {
                    if (useCustomMarker)
                      Marker(
                        markerId: const MarkerId('delivery_boy'),
                        position: LatLng(pos.latitude, pos.longitude),
                        icon: _bikeMarkerIcon!,
                        anchor: const Offset(0.5, 0.5),
                        rotation: pos.heading,
                      ),
                    if (_routeDestination != null)
                      Marker(
                        markerId: const MarkerId('route_destination'),
                        position: _routeDestination!,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueRed,
                        ),
                      ),
                  },
                  circles: {
                    Circle(
                        circleId: const CircleId('live_location_pulse'),
                        center: LatLng(pos.latitude, pos.longitude),
                        radius: 50 + (_pulsePhase * 55),
                        fillColor: AppColors.primary.withValues(alpha: (1 - _pulsePhase) * 0.16),
                        strokeColor: AppColors.online.withValues(alpha: (1 - _pulsePhase) * 0.55),
                        strokeWidth: 3,
                      ),
                  }, 
                  polylines: {
                    if (_routePoints.length > 1)
                      Polyline(
                        polylineId: const PolylineId('active_route'),
                        points: _routePoints,
                        color: Theme.of(context).primaryColor,
                        width: 5,
                      ),
                  },
                  myLocationEnabled: !useCustomMarker,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: false,
                  mapToolbarEnabled: false,
                  style: MapStyles.mutedGrey,
                );
              },
            ),
            Positioned(
              right: 16.w,
              bottom: 260.h,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticService.light();
                      final pos = ref.read(locationServiceProvider).lastPosition;
                      if (pos != null && _mapController != null) {
                        _mapController!.animateCamera(
                          // Zoom in fully to 18.0 for a close-up view
                          CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 18.0),
                        );
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.all(10.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Icon(Icons.my_location_rounded, color: Colors.black87, size: 22.sp),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  GestureDetector(
                    onTap: () {
                      HapticService.light();
                      final ordersState = ref.read(ordersControllerProvider);
                      if (ordersState is OrdersLoaded && ordersState.hasActiveOrder) {
                        final order = ordersState.currentOrder!;
                        final navigateToStore = order.currentPhase == 'en_route_to_pickup' || order.currentPhase == 'at_pickup';
                        final lat = navigateToStore ? order.store.location?.lat : order.deliveryAddress.location?.lat;
                        final lng = navigateToStore ? order.store.location?.lng : order.deliveryAddress.location?.lng;
                        if (lat != null && lng != null) {
                          MapLauncher.launchGoogleMaps(lat, lng);
                          return;
                        }
                      }
                      
                      final pos = ref.read(locationServiceProvider).lastPosition;
                      if (pos != null && _mapController != null) {
                        _mapController!.animateCamera(
                          CameraUpdate.newCameraPosition(
                            CameraPosition(
                              target: LatLng(pos.latitude, pos.longitude),
                              zoom: 17,
                              bearing: pos.heading,
                              tilt: 45,
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.all(10.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Icon(Icons.navigation_rounded, color: Colors.blueAccent, size: 22.sp),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
  }

}
