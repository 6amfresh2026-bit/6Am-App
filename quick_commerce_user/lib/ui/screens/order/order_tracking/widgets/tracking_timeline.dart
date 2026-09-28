import 'package:flutter/material.dart';

import '../../../../../core/constants/app_durations.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../domain/model/order.dart';
import '../../../../../domain/model/order_status.dart';

/// Vertical stepper: placed → confirmed → packing → out for delivery →
/// delivered, with the timestamp each milestone was reached.
class TrackingTimeline extends StatelessWidget {
  const TrackingTimeline({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    if (order.status.isCancelled) {
      return _CancelledNotice(order: order);
    }

    return Column(
      children: [
        for (final step in TrackingStep.values)
          _Step(
            step: step,
            reached: order.isStepReached(step),
            isCurrent: order.currentStep == step,
            isLast: step == TrackingStep.values.last,
            timestamp: order.statusTimestamps[step],
          ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.step,
    required this.reached,
    required this.isCurrent,
    required this.isLast,
    this.timestamp,
  });

  final TrackingStep step;
  final bool reached;
  final bool isCurrent;
  final bool isLast;
  final DateTime? timestamp;

  @override
  Widget build(BuildContext context) {
    final activeColor = context.semantic.success;
    final idleColor = context.semantic.border;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: AppDurations.medium,
                curve: Curves.easeOutBack,
                height: 26,
                width: 26,
                decoration: BoxDecoration(
                  color: reached ? activeColor : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: reached ? activeColor : idleColor,
                    width: 2,
                  ),
                ),
                child: reached
                    ? Icon(Icons.check_rounded, size: 15, color: context.colors.surface)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: reached ? activeColor : idleColor,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: isCurrent
                        ? context.text.titleLarge
                        : context.text.titleMedium!.copyWith(
                            color: reached
                                ? context.colors.onSurface
                                : context.semantic.textSecondary,
                          ),
                  ),
                  if (timestamp != null && reached)
                    Text(_time(timestamp!), style: context.text.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _time(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
  }
}

class _CancelledNotice extends StatelessWidget {
  const _CancelledNotice({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.semantic.dangerSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cancel_rounded, color: context.semantic.danger),
              const SizedBox(width: AppSpacing.md),
              Text(order.status.label, style: context.text.titleLarge),
            ],
          ),
          if (order.cancellationReason.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(order.cancellationReason, style: context.text.bodyMedium),
          ],
          if (order.pricing.total > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Any amount paid is refunded to the original payment method.',
              style: context.text.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
