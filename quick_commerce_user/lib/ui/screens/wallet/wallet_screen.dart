import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/extensions/num_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../di/repository_providers.dart';
import '../../../domain/model/user.dart';
import '../../../platform/payment/razorpay_checkout.dart';
import '../../common/widgets/buttons/primary_button.dart';
import '../../common/widgets/feedback/app_toast.dart';
import '../../common/widgets/loaders/shimmer_box.dart';
import 'wallet_provider.dart';
import '../../common/widgets/misc/sound_refresh_indicator.dart';

/// Fully functional Wallet & Transactions Screen.
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final TextEditingController _amountController = TextEditingController();
  bool _isAddingFunds = false;
  String _selectedFilter = 'All'; // 'All', 'Credits', 'Debits'

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  /// Real wallet top-up. Nothing is credited here: the backend mints a Razorpay
  /// order, the user pays through the gateway, and the backend re-checks the
  /// signature before it moves any money — the returned wallet is the source of
  /// truth. This replaced a simulated 800ms delay that announced success
  /// without ever charging or crediting anything.
  Future<void> _addFunds(double amount) async {
    if (amount <= 0) return;
    setState(() => _isAddingFunds = true);

    final auth = ref.read(authRepositoryProvider);
    final gateway = ref.read(paymentGatewayProvider);
    final user = auth.cachedUser;

    try {
      final order = await auth.createWalletTopupOrder(amount);

      final outcome = await gateway.open(
        key: order.key,
        gatewayOrderId: order.orderId,
        amountPaise: order.amountPaise,
        currency: order.currency,
        orderReference: 'Wallet top-up',
        customerName: user?.name ?? '',
        customerEmail: user?.email ?? '',
        customerPhone: user?.phone ?? '',
      );

      if (!mounted) return;

      switch (outcome) {
        case PaymentSucceeded(:final paymentId, :final signature):
          await auth.verifyWalletTopup(
            orderId: order.orderId,
            paymentId: paymentId,
            signature: signature,
            amountRupees: amount,
          );
          _amountController.clear();
          ref.invalidate(walletProvider);
          if (mounted) {
            AppToast.success(
              context,
              '${amount.asCurrency} added to your wallet',
            );
          }
        case PaymentCancelled():
          AppToast.info(
            context,
            'Top-up cancelled. You have not been charged.',
          );
        case PaymentFailed(:final message):
          AppToast.error(context, message);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, ErrorMapper.toFailure(e).message);
      }
    } finally {
      if (mounted) setState(() => _isAddingFunds = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletProvider);
    final user = ref.watch(authRepositoryProvider).cachedUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Wallet & Payments', style: context.text.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(walletProvider),
          ),
        ],
      ),
      body: SoundRefreshIndicator(
        color: const Color(0xFF43B5A8),
        //color: const Color(0xFFFFC107),
        onRefresh: () async {
          ref.invalidate(walletProvider);
          await ref.read(walletProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Golden Gradient Main Wallet Card
              walletAsync.when(
                data: (wallet) => _buildWalletCard(wallet, user),
                loading: () => const ShimmerBox(
                  width: double.infinity,
                  height: 180,
                  radius: BorderRadius.all(Radius.circular(20)),
                ),
                // Never invent a balance on error. Showing a fabricated
                // "₹250" told the user they had money they did not; a wallet
                // that could not load says so and offers a retry.
                error: (err, stack) => _WalletLoadError(
                  onRetry: () => ref.invalidate(walletProvider),
                ),
              ),

              const SizedBox(height: 20),

              // 2. Add Money / Top Up Section
              _buildAddMoneySection(),

              const SizedBox(height: 24),

              // 3. Referral Rewards Banner
              if (user != null) _buildReferralCard(user),

              const SizedBox(height: 24),

              // 4. Transaction History Header & Filter
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Transaction History',
                    style: context.text.titleMedium!.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Colors.white,
                      // color: const Color(0xFF1F2937),
                    ),
                  ),
                  Row(
                    children: ['All', 'Credits', 'Debits'].map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedFilter = filter),
                        child: Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF43B5A8)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            filter,
                            style: context.text.labelSmall!.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w900
                                  : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF1F2937),

                              // color: const Color(0xFF1F2937),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 5. Transactions List
              walletAsync.when(
                data: (wallet) => _buildTransactionsList(wallet.transactions),
                loading: () => Column(
                  children: List.generate(
                    3,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: ShimmerBox(
                        width: double.infinity,
                        height: 64,
                        radius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                ),
                error: (err, stack) => _buildTransactionsList(const []),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalletCard(Wallet wallet, User? user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF24665E), Color(0xFF43B5A8), Color(0xFF82CEC5)],
          // colors: [Color(0xFFFFB300), Color(0xFFFFC107), Color(0xFFFFD54F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF43B5A8).withValues(alpha: 0.35),
            //color: const Color(0xFFFFC107).withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      // color: Color(0xFF1F2937),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Suvio Wallet Balance',
                    style: context.text.titleSmall!.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      // color: const Color(0xFF1F2937),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '100% Secure',
                  style: context.text.labelSmall!.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF15803D),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            wallet.balance.asCurrency,
            style: context.text.displayLarge!.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 34,
              color: Colors.white,
              // color: const Color(0xFF1F2937),
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.black.withValues(alpha: 0.1), height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Referral Bonus Earned: ${wallet.referralEarnings.asCurrency}',
                style: context.text.bodySmall!.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  // color: const Color(0xFF374151),
                  fontSize: 11.5,
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: Colors.white,
                // color: Color(0xFF1F2937),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddMoneySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Top Up',
            style: context.text.titleSmall!.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Colors.white,
              // color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [100.0, 200.0, 500.0, 1000.0].map((amt) {
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    _amountController.text = amt.toInt().toString();
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '+ ₹${amt.toInt()}',
                      style: context.text.labelSmall!.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFD97706),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Enter amount (e.g. ₹500)',
              prefixIcon: Icon(
                Icons.currency_rupee_rounded,
                size: 18,
                color: Color(0xFF6B7280),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Add Money to Wallet',
            icon: Icons.add_circle_outline_rounded,
            isLoading: _isAddingFunds,
            onPressed: () {
              final val = double.tryParse(_amountController.text.trim());
              if (val != null && val > 0) {
                _addFunds(val);
              } else {
                AppToast.error(context, 'Please enter a valid amount');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCard(User user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Refer & Earn ₹50',
                  style: context.text.titleSmall!.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: const Color(0xFF14532D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Share your referral code: ${user.referralCode.isNotEmpty ? user.referralCode : "SUV50"}',
                  style: context.text.bodySmall!.copyWith(
                    fontSize: 11,
                    color: const Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Share.share(
                'Join me on Suvio Quick! Use code ${user.referralCode} to get ₹50 free wallet balance!',
              );
            },
            child: const Text(
              'Share',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(List<WalletTransaction> list) {
    // Real history only. An empty list means no transactions — the empty state
    // below says so. It used to be swapped for three invented rows ("Payment
    // for Order #1089", a ₹250 top-up), which every new user saw as their own.
    final filtered = list.where((t) {
      if (_selectedFilter == 'Credits') return t.isCredit;
      if (_selectedFilter == 'Debits') return !t.isCredit;
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 8),
            Text(
              'No transactions found',
              style: context.text.bodyMedium!.copyWith(
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: filtered.map((tx) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF3F4F6)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tx.isCredit
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  tx.isCredit
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: tx.isCredit
                      ? const Color(0xFF15803D)
                      : const Color(0xFFDC2626),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.description.isNotEmpty
                          ? tx.description
                          : (tx.isCredit ? 'Wallet Top Up' : 'Order Payment'),
                      style: context.text.titleSmall!.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.white,
                        // color: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tx.date.day} ${_monthName(tx.date.month)} ${tx.date.year}',
                      style: context.text.bodySmall!.copyWith(
                        fontSize: 10.5,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${tx.isCredit ? '+' : '-'} ${tx.amount.asCurrency}',
                    style: context.text.titleSmall!.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                      color: tx.isCredit
                          ? const Color(0xFF15803D)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tx.status,
                      style: context.text.labelSmall!.copyWith(
                        fontSize: 9,
                        color: const Color(0xFF4B5563),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[(month - 1).clamp(0, 11)];
  }
}

/// Shown when the wallet balance cannot be loaded. Deliberately carries no
/// number — an unreachable balance is unknown, not zero and not ₹250.
class _WalletLoadError extends StatelessWidget {
  const _WalletLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.semantic.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 34,
            color: context.semantic.textSecondary,
          ),
          const SizedBox(height: 10),
          Text(
            'Could not load your balance',
            style: context.text.titleSmall!.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Check your connection and try again.',
            textAlign: TextAlign.center,
            style: context.text.bodySmall!.copyWith(
              color: context.semantic.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
