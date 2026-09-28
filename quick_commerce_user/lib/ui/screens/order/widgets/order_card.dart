import 'package:flutter/material.dart';

import '../../../../core/extensions/num_extensions.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../common/delivery_promise.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/model/order.dart';
import '../../../common/widgets/buttons/secondary_button.dart';
import '../../../common/widgets/misc/app_network_image.dart';
import 'order_status_chip.dart';

/// A row in the orders list. Live orders get the tracking CTA.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    required this.onTrack,
    this.highlighted = false,
  });

  final Order order;
  final VoidCallback onTap;
  final VoidCallback onTrack;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadii.rLg,
          border: Border.all(
            color:
                highlighted ? context.colors.primary : context.semantic.border,
            width: highlighted ? 1.6 : 1,
          ),
          boxShadow: highlighted ? context.semantic.cardShadow : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.sellerName.isEmpty ? 'Suvio Quick' : order.sellerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium,
                  ),
                ),
                OrderStatusChip(status: order.status),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${order.displayId} · ${_date(order.placedAt)}',
              style: context.text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                for (final line in order.lines.take(4))
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ClipRRect(
                      borderRadius: AppRadii.rSm,
                      child: AppNetworkImage(
                        url: line.imageUrl,
                        height: 42,
                        width: 42,
                      ),
                    ),
                  ),
                if (order.lines.length > 4)
                  Container(
                    height: 42,
                    width: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.semantic.surfaceAlt,
                      borderRadius: AppRadii.rSm,
                    ),
                    child: Text(
                      '+${order.lines.length - 4}',
                      style: context.text.labelMedium,
                    ),
                  ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}',
                      style: context.text.bodySmall,
                    ),
                    Text(order.pricing.total.asCurrency,
                        style: context.text.price),
                  ],
                ),
              ],
            ),
            if (order.status.isActive) ...[
              const SizedBox(height: AppSpacing.md),
              SecondaryButton(
                label: order.isBookingAt(DateTime.now()) ||
                        order.etaMinutes != null
                    ? 'Track order · ${DeliveryPromise.forOrder(order)}'
                    : 'Track order',
                icon: Icons.delivery_dining_rounded,
                expand: true,
                onPressed: onTrack,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _date(DateTime time) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '${time.day} ${months[time.month - 1]}, $hour:$minute $period';
  }
}
