import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../di/app_providers.dart';
import '../../../../di/repository_providers.dart';
import '../../../../navigation/route_paths.dart';
import '../../../common/widgets/feedback/app_dialog.dart';
import '../../../common/widgets/feedback/app_toast.dart';
import '../../../common/widgets/misc/app_network_image.dart';

/// Signed out has no wallet to show — 0, not a made-up balance. An API
/// failure propagates as an [AsyncValue.error] instead of being swallowed
/// into the same fake number, so the UI can tell "no money" from "couldn't
/// load" and offer a retry for the latter.
final walletProvider = FutureProvider<int>((ref) async {
  if (!ref.watch(authProvider).isSignedIn) return 0;
  final walletData = await ref.read(authRepositoryProvider).wallet();
  return walletData.balance.toInt();
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notificationsEnabled = true;
  bool _nonVegModeEnabled = false;

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF108061);
    const darkTextColor = Color(0xFF142922);
    const lightBg = Color(0xFFF4FAF7);
    const cardBorderColor = Color(0xFFDFE8E3);
    const secondaryTextColor = Color(0xFF758A82);

    final auth = ref.watch(authProvider);
    final user = auth.user;
    final selectedAddress = ref.watch(selectedAddressProvider);
    final walletAsync = ref.watch(walletProvider);
    final walletBalance = walletAsync.valueOrNull ?? 0;
    final walletFailed = walletAsync.hasError;

    final userName = user?.displayName ?? 'Guest';
    final userPhone = user?.maskedPhone ?? '';
    final userAddress = selectedAddress != null
        ? '${selectedAddress.street}, ${selectedAddress.city}'
        : 'Add a delivery address';

    return Scaffold(
      backgroundColor: lightBg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card with Gradient & Profile
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0E7C66), Color(0xFF108061)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    // Avatar Image with White Ring Border
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x20000000),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: (user?.profileImage ?? '').isNotEmpty
                            ? AppNetworkImage(
                                url: user!.profileImage,
                                fit: BoxFit.cover,
                                fallbackIcon: Icons.person,
                              )
                            : const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 36,
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // User Name & Phone
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userPhone,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xD0FFFFFF),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Edit Pencil Button
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: () => context.push(RoutePaths.editProfile),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Address & Wallet Summary Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorderColor),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x08108061),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Address Tile
                      GestureDetector(
                        onTap: () => context.push(RoutePaths.addresses),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: primaryGreen,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                userAddress,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: darkTextColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF99AAA3),
                              size: 20,
                            ),
                          ],
                        ),
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(color: cardBorderColor, height: 1),
                      ),

                      // Wallet Balance Tile
                      Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: primaryGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Wallet Balance',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: secondaryTextColor,
                                  ),
                                ),
                                Text(
                                  walletFailed ? 'Unable to load' : '₹$walletBalance',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: walletFailed ? secondaryTextColor : darkTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // View Wallet Pill Button
                          GestureDetector(
                            onTap: () => context.push(RoutePaths.wallet),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFFBF5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFBCEBD7)),
                              ),
                              child: const Text(
                                'View Wallet',
                                style: TextStyle(
                                  color: primaryGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // My Account Section Header
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'My Account',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: darkTextColor,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Account Options List Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorderColor),
                  ),
                  child: Column(
                    children: [
                      _AccountMenuItem(
                        icon: Icons.location_on_outlined,
                        title: 'My Addresses',
                        onTap: () => context.push(RoutePaths.addresses),
                      ),
                      _AccountMenuItem(
                        icon: Icons.assignment_outlined,
                        title: 'Your Orders',
                        onTap: () => context.go(RoutePaths.orders),
                      ),
                      _AccountMenuItem(
                        icon: Icons.event_repeat_rounded,
                        title: 'Subscriptions',
                        onTap: () => context.push(RoutePaths.subscriptions),
                      ),
                      _AccountMenuItem(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Wallet & Rewards',
                        onTap: () => context.push(RoutePaths.wallet),
                      ),
                      _AccountMenuItem(
                        icon: Icons.local_offer_outlined,
                        title: 'Coupons',
                        onTap: () => context.push(RoutePaths.coupons),
                      ),
                      _AccountMenuItem(
                        icon: Icons.notifications_none_rounded,
                        title: 'Notifications',
                        trailingWidget: Switch(
                          value: _notificationsEnabled,
                          activeTrackColor: primaryGreen,
                          onChanged: (val) {
                            setState(() => _notificationsEnabled = val);
                            AppToast.show(
                              context,
                              val ? 'Notifications enabled' : 'Notifications disabled',
                            );
                          },
                        ),
                      ),
                      _AccountMenuItem(
                        icon: Icons.circle_outlined,
                        title: 'NonVeg Mode',
                        trailingWidget: Switch(
                          value: _nonVegModeEnabled,
                          activeTrackColor: primaryGreen,
                          onChanged: (val) {
                            setState(() => _nonVegModeEnabled = val);
                          },
                        ),
                      ),
                      _AccountMenuItem(
                        icon: Icons.headset_mic_outlined,
                        title: 'Help & Support',
                        onTap: () => context.push(RoutePaths.help),
                      ),
                      _AccountMenuItem(
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        onTap: () => context.push(RoutePaths.settings),
                      ),
                      _AccountMenuItem(
                        icon: Icons.logout_rounded,
                        title: 'Logout',
                        isLast: true,
                        onTap: () => _confirmLogout(context, ref),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Bottom Promo Banner Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDF7EC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: primaryGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.eco_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fresh Choices. Better Living.',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: primaryGreen,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Healthy food  •  Happy you',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF336B59),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.park_rounded,
                        color: Color(0xFF81C7A5),
                        size: 28,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialog.confirm(
      context,
      icon: Icons.logout_rounded,
      title: 'Log out of 6AM Fresh?',
      message: 'Your cart and saved items stay safe on your account.',
      confirmLabel: 'Log out',
      destructive: true,
    );
    if (confirmed) {
      await ref.read(authProvider.notifier).signOut();
      if (mounted && context.mounted) {
        context.go(RoutePaths.login);
      }
    }
  }
}

class _AccountMenuItem extends StatelessWidget {
  const _AccountMenuItem({
    required this.icon,
    required this.title,
    this.onTap,
    this.trailingWidget,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Widget? trailingWidget;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    const darkTextColor = Color(0xFF142922);
    const primaryGreen = Color(0xFF108061);

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: primaryGreen, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: darkTextColor,
                    ),
                  ),
                ),
                if (trailingWidget != null)
                  trailingWidget!
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF99AAA3),
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: Color(0xFFEFF3F1), height: 1),
          ),
      ],
    );
  }
}
