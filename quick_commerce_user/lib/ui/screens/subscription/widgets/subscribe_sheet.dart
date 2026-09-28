import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_labels.dart';
import '../../../../di/app_providers.dart';
import '../../../../di/service_providers.dart';
import '../../../../domain/model/payment_method.dart';
import '../../../../domain/model/product.dart';
import '../../../../domain/model/product_subscription.dart';
import '../../../../domain/model/product_variant.dart';
import '../../../../navigation/route_paths.dart';
import '../../../common/widgets/buttons/primary_button.dart';
import '../../../common/widgets/feedback/app_bottom_sheet.dart';
import '../../../common/widgets/feedback/app_toast.dart';
import '../../../common/widgets/misc/quantity_stepper.dart';
import '../subscriptions_provider.dart';

/// Sets up recurring auto-delivery for one product.
///
/// Validation mirrors the backend's own rules (see [SubscriptionScheduleService])
/// so a bad schedule is caught in the sheet rather than as a 400 on submit.
abstract final class SubscribeSheet {
  /// Methods the subscription endpoint accepts — narrower than checkout.
  static const _methods = [
    PaymentMethod.cash,
    PaymentMethod.upi,
    PaymentMethod.wallet,
  ];

  static Future<bool?> show(
    BuildContext context, {
    required Product product,
    ProductVariant? variant,
  }) =>
      AppBottomSheet.show<bool>(
        context,
        title: 'Subscribe',
        subtitle: product.name,
        expand: false,
        child: _SubscribeBody(
          product: product,
          variant: variant,
          methods: _methods,
        ),
      );
}

class _SubscribeBody extends ConsumerStatefulWidget {
  const _SubscribeBody({
    required this.product,
    required this.variant,
    required this.methods,
  });

  final Product product;
  final ProductVariant? variant;
  final List<PaymentMethod> methods;

  @override
  ConsumerState<_SubscribeBody> createState() => _SubscribeBodyState();
}

class _SubscribeBodyState extends ConsumerState<_SubscribeBody> {
  int _quantity = 1;
  SubscriptionFrequency _frequency = SubscriptionFrequency.daily;
  final Set<int> _daysOfWeek = {};
  int _dayOfMonth = 1;
  TimeOfDay _time = const TimeOfDay(hour: 7, minute: 0);
  late DateTime _startDate;
  PaymentMethod _method = PaymentMethod.cash;
  Map<String, String> _errors = const {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Today is a valid start date server-side, so it is the sensible default.
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
  }

  String get _deliveryTime =>
      '${_time.hour.toString().padLeft(2, '0')}:'
      '${_time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final address = ref.watch(selectedAddressProvider);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 20.0 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(context, 'How many each time'),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.variant?.name.isNotEmpty == true
                      ? widget.variant!.name
                      : widget.product.unitLabel,
                  style: context.text.bodyMedium?.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              QuantityStepper(
                quantity: _quantity,
                onIncrement: () => setState(() => _quantity++),
                onDecrement: () =>
                    setState(() => _quantity = _quantity > 1 ? _quantity - 1 : 1),
              ),
            ],
          ),
          const SizedBox(height: 18.0),

          _label(context, 'How often'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: SubscriptionFrequency.values
                .map(
                  (frequency) => ChoiceChip(
                    label: Text(frequency.label),
                    selected: _frequency == frequency,
                    onSelected: (_) => setState(() => _frequency = frequency),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    selectedColor: context.colors.primary.withValues(alpha: 0.12),
                    labelStyle: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                          _frequency == frequency ? FontWeight.w600 : FontWeight.w400,
                      color: _frequency == frequency
                          ? context.colors.primary
                          : context.colors.onSurface,
                    ),
                    side: BorderSide(
                      color: _frequency == frequency
                          ? context.colors.primary
                          : context.semantic.border,
                    ),
                  ),
                )
                .toList(),
          ),

          if (_frequency.needsDaysOfWeek) ...[
            const SizedBox(height: 18.0),
            _label(context, 'Which days'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: List.generate(7, (day) {
                final selected = _daysOfWeek.contains(day);
                return FilterChip(
                  label: Text(DateLabels.weekdayShort(day)),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    if (selected) {
                      _daysOfWeek.remove(day);
                    } else {
                      _daysOfWeek.add(day);
                    }
                  }),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  selectedColor: context.colors.primary.withValues(alpha: 0.12),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? context.colors.primary
                        : context.colors.onSurface,
                  ),
                  side: BorderSide(
                    color: selected
                        ? context.colors.primary
                        : context.semantic.border,
                  ),
                );
              }),
            ),
            _error(context, 'daysOfWeek'),
          ],

          if (_frequency.needsDayOfMonth) ...[
            const SizedBox(height: 18.0),
            _label(context, 'Day of the month'),
            DropdownButtonFormField<int>(
              initialValue: _dayOfMonth,
              items: List.generate(28, (i) => i + 1)
                  .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                  .toList(),
              onChanged: (value) => setState(() => _dayOfMonth = value ?? 1),
            ),
            _error(context, 'dayOfMonth'),
          ],

          const SizedBox(height: 18.0),
          Row(
            children: [
              Expanded(
                child: _PickerTile(
                  icon: Icons.schedule_rounded,
                  label: 'Delivery time',
                  value: DateLabels.clockFromWire(_deliveryTime),
                  onTap: _pickTime,
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: _PickerTile(
                  icon: Icons.event_rounded,
                  label: 'Starts',
                  value: DateLabels.relativeDay(_startDate),
                  onTap: _pickStartDate,
                ),
              ),
            ],
          ),
          _error(context, 'startDate'),

          const SizedBox(height: 18.0),
          _label(context, 'Payment'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: widget.methods
                .map(
                  (method) => ChoiceChip(
                    label: Text(method.label),
                    selected: _method == method,
                    onSelected: (_) => setState(() => _method = method),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    selectedColor: context.colors.primary.withValues(alpha: 0.12),
                    labelStyle: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                          _method == method ? FontWeight.w600 : FontWeight.w400,
                      color: _method == method
                          ? context.colors.primary
                          : context.colors.onSurface,
                    ),
                    side: BorderSide(
                      color: _method == method
                          ? context.colors.primary
                          : context.semantic.border,
                    ),
                  ),
                )
                .toList(),
          ),

          const SizedBox(height: 18.0),
          _AddressTile(address: address?.shortLine),
          _error(context, 'addressId'),

          const SizedBox(height: 22.0),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'Start subscription',
              isLoading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
          ),
          const SizedBox(height: 12.0),
          Text(
            'Orders are placed automatically on each scheduled day. You can skip '
            'a single delivery up to the night before, or pause any time.',
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(
              color: context.semantic.textSecondary,
              fontSize: 12.0,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
        child: Text(
          text,
          style: context.text.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 15.0,
          ),
        ),
      );

  Widget _error(BuildContext context, String key) {
    final message = _errors[key];
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        message,
        style: context.text.labelSmall?.copyWith(color: context.semantic.danger),
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate.isBefore(today) ? today : _startDate,
      // The backend refuses a past start date, so the picker cannot offer one.
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _submit() async {
    final address = ref.read(selectedAddressProvider);
    final schedule = ref.read(subscriptionScheduleServiceProvider);

    final errors = schedule.validateDraft(
      frequency: _frequency,
      deliveryTime: _deliveryTime,
      startDate: _startDate,
      addressId: address?.id ?? '',
      quantity: _quantity,
      daysOfWeek: _daysOfWeek.toList(),
      dayOfMonth: _dayOfMonth,
    );
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    setState(() => _submitting = true);
    final created = await ref.read(subscriptionsProvider.notifier).create(
          restaurantId: widget.product.sellerId,
          itemId: widget.product.id,
          variantId: widget.variant?.id,
          quantity: _quantity,
          frequency: _frequency,
          daysOfWeek: _daysOfWeek.toList()..sort(),
          dayOfMonth: _dayOfMonth,
          deliveryTime: _deliveryTime,
          startDate: _startDate,
          addressId: address!.id,
          method: _method,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (created == null) {
      AppToast.error(
        context,
        ref.read(subscriptionsProvider).failure?.message ??
            'Could not start that subscription.',
      );
      ref.read(subscriptionsProvider.notifier).clearFailure();
      return;
    }

    Navigator.of(context).pop(true);
    AppToast.success(
      context,
      'Subscription started',
      actionLabel: 'View',
      onAction: () => context.push(RoutePaths.subscriptionDetailsOf(created.id)),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.semantic.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: context.colors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: context.text.labelSmall?.copyWith(
                      color: context.semantic.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: context.text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({required this.address});

  final String? address;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: context.semantic.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 20,
            color: context.colors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              address ?? 'Choose a delivery address first',
              style: context.text.bodySmall?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
