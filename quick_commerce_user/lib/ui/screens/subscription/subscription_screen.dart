import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/date_labels.dart';
import '../../../domain/model/product.dart';
import '../../../domain/model/product_subscription.dart';
import '../../../di/app_providers.dart';
import '../../../navigation/route_paths.dart';
import '../../common/widgets/feedback/app_toast.dart';
import '../../common/widgets/misc/app_network_image.dart';
import 'subscriptions_provider.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({
    super.key,
    this.product,
  });

  final Product? product;

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  int _quantity = 1;
  SubscriptionFrequency _frequency = SubscriptionFrequency.monthly;
  late DateTime _startDate;
  TimeOfDay _deliveryTime = const TimeOfDay(hour: 9, minute: 0);
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Tomorrow: the earliest date the backend accepts is "not in the past",
    // but a day's buffer means the customer is never racing today's cutoff.
    _startDate = DateTime.now().add(const Duration(days: 1));
  }

  double get _unitPrice => widget.product!.price;
  double? get _mrp => widget.product!.mrp;

  /// The product's own markdown vs MRP — real, independent of frequency.
  int get _productDiscountPercent {
    final mrp = _mrp;
    if (mrp == null || mrp <= _unitPrice) return 0;
    return (((mrp - _unitPrice) / mrp) * 100).round();
  }

  int _discountPercentFor(
    SubscriptionFrequency frequency,
    Map<SubscriptionFrequency, int> config,
  ) =>
      config[frequency] ?? 0;

  double get _subtotal => _unitPrice * _quantity;

  double _savingsFor(int discountPercent) =>
      (_subtotal * discountPercent / 100).roundToDouble();

  double _totalFor(int discountPercent) => _subtotal - _savingsFor(discountPercent);

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF108061),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF142922),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectDeliveryTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _deliveryTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF108061),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF142922),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _deliveryTime = picked);
    }
  }

  String get _deliveryTimeWire =>
      '${_deliveryTime.hour.toString().padLeft(2, '0')}:'
      '${_deliveryTime.minute.toString().padLeft(2, '0')}';

  String get _deliveryTimeLabel {
    final hour = _deliveryTime.hourOfPeriod == 0 ? 12 : _deliveryTime.hourOfPeriod;
    final minute = _deliveryTime.minute.toString().padLeft(2, '0');
    final period = _deliveryTime.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _submitSubscription(Map<SubscriptionFrequency, int> discountConfig) async {
    final product = widget.product!;
    final address = ref.read(selectedAddressProvider);
    if (address == null) {
      AppToast.error(context, 'Please select a delivery address first.');
      context.push(RoutePaths.addresses);
      return;
    }

    setState(() => _isSubmitting = true);
    final created = await ref.read(subscriptionsProvider.notifier).create(
          restaurantId: product.sellerId,
          itemId: product.id,
          quantity: _quantity,
          frequency: _frequency,
          deliveryTime: _deliveryTimeWire,
          startDate: _startDate,
          addressId: address.id,
          // Weekly repeats on the same weekday as the start date; monthly on
          // the same day of month (capped at 28, same as the backend). This
          // keeps the recurrence tied to the one date the customer actually
          // picked, rather than asking them to pick it twice.
          daysOfWeek: _frequency.needsDaysOfWeek ? [_startDate.weekday % 7] : const [],
          dayOfMonth: _frequency.needsDayOfMonth ? _startDate.day.clamp(1, 28) : null,
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (created != null) {
      AppToast.success(context, 'Subscribed to ${product.name} successfully!');
      context.pop(true);
      return;
    }

    final failure = ref.read(subscriptionsProvider).failure;
    AppToast.error(context, failure?.message ?? 'Could not create the subscription.');
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF108061);
    const darkTextColor = Color(0xFF142922);
    const lightBg = Color(0xFFF4FAF7);

    final product = widget.product;
    if (product == null) {
      return Scaffold(
        backgroundColor: lightBg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: darkTextColor),
                      onPressed: () => context.pop(),
                    ),
                    const Text(
                      'Subscription',
                      style: TextStyle(
                        color: darkTextColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: Center(child: Text('No product selected for this subscription.')),
              ),
            ],
          ),
        ),
      );
    }

    final discountConfigAsync = ref.watch(subscriptionDiscountConfigProvider);
    final discountConfig = discountConfigAsync.valueOrNull ?? const {};
    final selectedPercent = _discountPercentFor(_frequency, discountConfig);
    final totalPerDelivery = _totalFor(selectedPercent);
    final savings = _savingsFor(selectedPercent);
    final address = ref.watch(selectedAddressProvider);

    const cardBorderColor = Color(0xFFDFE8E3);
    const secondaryTextColor = Color(0xFF758A82);

    final formattedDate =
        '${DateLabels.month(_startDate.month)} ${_startDate.day}, ${_startDate.year}';

    return Scaffold(
      backgroundColor: lightBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: darkTextColor, size: 24),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Subscription',
                    style: TextStyle(
                      color: darkTextColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: darkTextColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cardBorderColor, width: 1),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A108061),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F9F8),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: AppNetworkImage(
                              url: product.imageUrl,
                              fit: BoxFit.contain,
                              fallbackIcon: Icons.local_drink_rounded,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: darkTextColor,
                                  ),
                                ),
                                if (product.packSize.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    product.packSize,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      '₹${_unitPrice.toInt()}',
                                      style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                        color: darkTextColor,
                                      ),
                                    ),
                                    if (_mrp != null && _mrp! > _unitPrice) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '₹${_mrp!.toInt()}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          decoration: TextDecoration.lineThrough,
                                          color: Color(0xFF99AAA3),
                                        ),
                                      ),
                                    ],
                                    if (_productDiscountPercent > 0) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDDF7EC),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '$_productDiscountPercent% OFF',
                                          style: const TextStyle(
                                            color: primaryGreen,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section 1: Choose Frequency
                    const Text(
                      'Choose Frequency',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: darkTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: SubscriptionFrequency.values.map((frequency) {
                        final percent = _discountPercentFor(frequency, discountConfig);
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: frequency == SubscriptionFrequency.values.last ? 0 : 10,
                            ),
                            child: _FrequencyCard(
                              title: frequency.label,
                              discountPercent: percent,
                              isLoading: discountConfigAsync.isLoading,
                              isSelected: _frequency == frequency,
                              onTap: () => setState(() => _frequency = frequency),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // Section 2: Delivery starts
                    const Text(
                      'Delivery starts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: darkTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _selectStartDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cardBorderColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              color: primaryGreen,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: darkTextColor,
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.date_range_rounded,
                              color: primaryGreen,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section 2b: Delivery time
                    const Text(
                      'Delivery time',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: darkTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _selectDeliveryTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cardBorderColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              color: primaryGreen,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _deliveryTimeLabel,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: darkTextColor,
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.edit_outlined,
                              color: primaryGreen,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section 3: Quantity
                    const Text(
                      'Quantity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: darkTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 150,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, color: primaryGreen, size: 20),
                            onPressed: _quantity > 1
                                ? () => setState(() => _quantity--)
                                : null,
                          ),
                          Text(
                            '$_quantity',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: darkTextColor,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, color: primaryGreen, size: 20),
                            onPressed: () => setState(() => _quantity++),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section 4: Delivery address
                    const Text(
                      'Deliver to',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: darkTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => context.push(RoutePaths.addresses),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: address == null ? Colors.redAccent : cardBorderColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              color: address == null ? Colors.redAccent : primaryGreen,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                address?.street ?? 'Select a delivery address',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: address == null ? Colors.redAccent : darkTextColor,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: primaryGreen,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Total & Savings Summary Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total (per delivery)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: secondaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${totalPerDelivery.toInt()}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: darkTextColor,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (savings > 0)
                          Text(
                            'You save ₹${savings.toInt()}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: primaryGreen,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Main Action CTA Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        onPressed: _isSubmitting
                            ? null
                            : () => _submitSubscription(discountConfig),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Subscribe',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrequencyCard extends StatelessWidget {
  const _FrequencyCard({
    required this.title,
    required this.discountPercent,
    required this.isSelected,
    required this.onTap,
    this.isLoading = false,
  });

  final String title;
  final int discountPercent;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF108061);
    const darkTextColor = Color(0xFF142922);
    const cardBorderColor = Color(0xFFDFE8E3);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFFBF5) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primaryGreen : cardBorderColor,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? primaryGreen : darkTextColor,
              ),
            ),
            const SizedBox(height: 4),
            if (isLoading)
              const SizedBox(
                height: 15,
                width: 15,
                child: CircularProgressIndicator(strokeWidth: 2, color: primaryGreen),
              )
            else if (discountPercent > 0) ...[
              Text(
                'Save',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: primaryGreen.withValues(alpha: 0.8),
                ),
              ),
              Text(
                '$discountPercent%',
                style: TextStyle(
                  fontSize: isSelected ? 17 : 15,
                  fontWeight: FontWeight.w800,
                  color: primaryGreen,
                ),
              ),
            ] else
              const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }
}
