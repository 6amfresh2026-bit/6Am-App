import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// The 3-column trust feature banner sitting under the search bar in the top yellow header.
/// The 3-column trust feature banner sitting under the search bar in the top yellow header.
class FeatureHighlightsRow extends StatelessWidget {
  const FeatureHighlightsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. 10 mins Fast Delivery
          const Expanded(
            child: _FeatureItem(
              iconWidget: Icon(
                Icons.two_wheeler_rounded,
                size: 20,
                color: Color(0xFF43B5A8),
                // color: Color(0xFFFFC107),
              ),
              title: '10 mins',
              subtitle: 'Fast Delivery',
            ),
          ),
          _divider(),
          // 2. 100% Secure Payment
          Expanded(
            child: _FeatureItem(
              iconWidget: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Color(0xFF43B5A8),
                  // color: Color(0xFFFFC107),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              ),
              title: '100%',
              subtitle: 'Secure Payment',
            ),
          ),
          _divider(),
          // 3. Best Prices On All Products
          Expanded(
            child: _FeatureItem(
              iconWidget: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Color(0xFF43B5A8),
                  // color: Color(0xFFFFC107),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  '%',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              title: 'Best Prices',
              subtitle: 'On All Products',
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 24,
      width: 1,
      color: const Color(0xFFF3F4F6),
      margin: const EdgeInsets.symmetric(horizontal: 2),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.iconWidget,
    required this.title,
    required this.subtitle,
  });

  final Widget iconWidget;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall!.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 11.5,
                  color: const Color(0xFF1F2937),
                  height: 1.1,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall!.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 9,
                  color: const Color(0xFF6B7280),
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
