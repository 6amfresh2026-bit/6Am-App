import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/num_extensions.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/model/order.dart';
import '../../../../navigation/route_paths.dart';
import '../../../common/widgets/buttons/primary_button.dart';
import '../../../common/widgets/buttons/secondary_button.dart';

class OrderSuccessScreen extends StatefulWidget {
  const OrderSuccessScreen({super.key, required this.order});

  final Order order;

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    // Back must not return to the payment sheet the order just came through,
    // but it must not be a dead key either — it lands on Home, which is where
    // the "Continue shopping" button goes.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(RoutePaths.home);
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => CustomPaint(
                      painter: _ConfettiPainter(
                        progress: _controller.value,
                        colors: [
                          context.colors.primary,
                          context.semantic.accent,
                          context.semantic.success,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    const Spacer(),
                    _CheckMorph(controller: _controller),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      'Order confirmed',
                      style: context.text.displaySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      order.etaMinutes != null
                          ? 'Arriving in about ${order.etaMinutes} minutes'
                          : 'We are packing it right now',
                      textAlign: TextAlign.center,
                      style: context.text.bodyLarge!
                          .copyWith(color: context.semantic.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: context.semantic.surfaceAlt,
                        borderRadius: AppRadii.rLg,
                      ),
                      child: Column(
                        children: [
                          _Row(label: 'Order ID', value: order.displayId),
                          const SizedBox(height: AppSpacing.sm),
                          _Row(
                            label: 'Items',
                            value: '${order.itemCount}',
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _Row(
                            label: 'Paid via',
                            value: order.paymentMethod.label,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _Row(
                            label: 'Total',
                            value: order.pricing.total.asCurrency,
                            emphasise: true,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    PrimaryButton(
                      label: 'Track your order',
                      icon: Icons.delivery_dining_rounded,
                      onPressed: () =>
                          context.go(RoutePaths.orderTrackingOf(order.id)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SecondaryButton(
                      label: 'Continue shopping',
                      expand: true,
                      onPressed: () => context.go(RoutePaths.home),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.emphasise = false,
  });

  final String label;
  final String value;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: context.text.bodyMedium),
        Text(
          value,
          style: emphasise ? context.text.price : context.text.titleSmall,
        ),
      ],
    );
  }
}

/// Circle that draws itself, then a tick that strokes in.
class _CheckMorph extends StatelessWidget {
  const _CheckMorph({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      width: 120,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final ring = Curves.easeOutCubic.transform(
            (controller.value / 0.45).clamp(0.0, 1.0),
          );
          final tick = Curves.easeOutBack.transform(
            ((controller.value - 0.35) / 0.4).clamp(0.0, 1.0),
          );

          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: CircularProgressIndicator(
                  value: ring,
                  strokeWidth: 4,
                  color: context.semantic.success,
                  backgroundColor: context.semantic.successSoft,
                ),
              ),
              Transform.scale(
                scale: tick,
                child: Icon(
                  Icons.check_rounded,
                  size: 56,
                  color: context.semantic.success,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Deterministic confetti — seeded per particle so it does not reshuffle on
/// every frame.
class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.progress, required this.colors});

  final double progress;
  final List<Color> colors;

  static const _count = 42;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1) return;

    for (var i = 0; i < _count; i++) {
      final seed = i / _count;
      final x = size.width * ((seed * 7.3) % 1);
      final drift = math.sin((progress + seed) * math.pi * 2) * 22;
      final y = -20 + (size.height + 60) * ((progress * 1.35) - seed * 0.3);
      if (y < -20 || y > size.height) continue;

      final paint = Paint()
        ..color = colors[i % colors.length]
            .withValues(alpha: (1 - progress).clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(x + drift, y);
      canvas.rotate((progress * 6 + seed * 3) % (math.pi * 2));
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 7, height: 11),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
