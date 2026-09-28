import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/num_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../di/app_providers.dart';
import '../../../../di/repository_providers.dart';
import '../../../../domain/model/user.dart';
import '../../../../navigation/route_paths.dart';
import '../../../common/widgets/buttons/primary_button.dart';
import '../../../common/widgets/feedback/app_dialog.dart';
import '../../../common/widgets/loaders/shimmer_box.dart';

/// Wallet balance for the profile card.
final walletProvider = FutureProvider<Wallet>((ref) async {
  if (!ref.watch(authProvider).isSignedIn) return const Wallet();
  return ref.read(authRepositoryProvider).wallet();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;

    return Scaffold(
      appBar: showAppBar ? AppBar(title: const Text('Account')) : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            if (user == null)
              const _SignedOutCard()
            else ...[
              _ProfileHeader(user: user),
              const _WalletCard(),
            ],
            const SizedBox(height: AppSpacing.lg),
            _MenuGroup(
              items: [
                _MenuItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Your orders',
                  onTap: () => context.go(RoutePaths.orders),
                ),
                _MenuItem(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Wallet & earnings',
                  onTap: () => context.push(RoutePaths.wallet),
                ),
                _MenuItem(
                  icon: Icons.location_on_rounded,
                  label: 'Saved addresses',
                  onTap: () => context.push(RoutePaths.addresses),
                ),
                _MenuItem(
                  icon: Icons.playlist_add_check_rounded,
                  label: 'Monthly lists',
                  onTap: () => context.push(RoutePaths.monthlyLists),
                ),
                _MenuItem(
                  icon: Icons.event_repeat_rounded,
                  label: 'Subscriptions',
                  onTap: () => context.push(RoutePaths.subscriptions),
                ),
                _MenuItem(
                  icon: Icons.favorite_rounded,
                  label: 'Wishlist',
                  onTap: () => context.push(RoutePaths.wishlist),
                ),
                _MenuItem(
                  icon: Icons.local_offer_rounded,
                  label: 'Offers & coupons',
                  onTap: () => context.push(RoutePaths.coupons),
                ),
                _MenuItem(
                  icon: Icons.notifications_rounded,
                  label: 'Notifications',
                  onTap: () => context.push(RoutePaths.notifications),
                ),
              ],
            ),
            _MenuGroup(
              items: [
                _MenuItem(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & support',
                  onTap: () => context.push(RoutePaths.help),
                ),
                _MenuItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  onTap: () => context.push(RoutePaths.settings),
                ),
                _MenuItem(
                  icon: Icons.shield_outlined,
                  label: 'Privacy policy',
                  onTap: () => context.push(RoutePaths.privacyPolicy),
                ),
                _MenuItem(
                  icon: Icons.description_outlined,
                  label: 'Terms of service',
                  onTap: () => context.push(RoutePaths.terms),
                ),
                _MenuItem(
                  icon: Icons.info_outline_rounded,
                  label: 'About Appzeto Quick',
                  onTap: () => context.push(RoutePaths.about),
                ),
              ],
            ),
            if (user != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: PrimaryButton(
                  label: 'Log out',
                  icon: Icons.logout_rounded,
                  destructive: true,
                  isLoading: auth.isLoading,
                  onPressed: () => _logout(context, ref),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialog.confirm(
      context,
      icon: Icons.logout_rounded,
      title: 'Log out of Appzeto Quick?',
      message: 'Your cart and saved items stay safe on your account.',
      confirmLabel: 'Log out',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    await ref.read(authProvider.notifier).signOut();
    if (context.mounted) context.go(RoutePaths.login);
  }
}

class _SignedOutCard extends StatelessWidget {
  const _SignedOutCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.07),
        borderRadius: AppRadii.rLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('You are browsing as a guest', style: context.text.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Sign in to place orders, track deliveries and keep your wishlist.',
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Sign in',
            expand: false,
            onPressed: () => context.push(RoutePaths.login),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: context.colors.primary.withValues(alpha: 0.12),
            child: Text(
              user.displayName.initials,
              style: context.text.headlineSmall!
                  .copyWith(color: context.colors.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName, style: context.text.headlineSmall),
                Text(user.maskedPhone, style: context.text.bodyMedium),
                if (user.email.isNotEmpty)
                  Text(user.email, style: context.text.bodySmall),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.push(RoutePaths.editProfile),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit profile',
          ),
        ],
      ),
    );
  }
}

class _WalletCard extends ConsumerWidget {
  const _WalletCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colors.primary,
            context.colors.primary.withValues(alpha: 0.78),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadii.rLg,
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet_rounded,
            color: context.colors.surface,
            size: 26,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suvio Wallet',
                  style: context.text.labelMedium!
                      .copyWith(color: context.colors.surface.withValues(alpha: 0.7)),
                ),
                wallet.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: ShimmerBox(width: 70, height: 16),
                  ),
                  error: (_, _) => Text(
                    'Balance unavailable',
                    style: context.text.titleMedium!
                        .copyWith(color: context.colors.surface),
                  ),
                  data: (data) => Text(
                    data.balance.asCurrency,
                    style: context.text.priceLarge.copyWith(color: context.colors.surface),
                  ),
                ),
              ],
            ),
          ),
          wallet.maybeWhen(
            data: (data) => data.referralEarnings > 0
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Referral earnings',
                        style: context.text.labelSmall!
                            .copyWith(color: context.colors.surface.withValues(alpha: 0.7)),
                      ),
                      Text(
                        data.referralEarnings.asCurrency,
                        style: context.text.titleSmall!
                            .copyWith(color: context.colors.surface),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.items});

  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: context.semantic.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            items[i],
            if (i != items.length - 1)
              Divider(height: 1, indent: 56, color: context.semantic.border),
          ],
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 20, color: context.colors.primary),
      title: Text(label, style: context.text.titleMedium),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: context.semantic.textSecondary,
      ),
    );
  }
}
