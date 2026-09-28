import 'package:flutter/material.dart';

import '../../../../core/extensions/num_extensions.dart';
import '../../../../domain/model/coupon.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../common/widgets/loaders/shimmer_box.dart';

/// Live offer cards under the hero banner.
///
/// One card per real coupon from `GET /food/restaurant/offers`. The row used to
/// render two fixed cards — "Top Offers" and a "Free Delivery / on orders above
/// ₹199" promise nothing in the backend backed — which stayed on screen, and
/// inert, when the merchant had published no offers at all.
class OfferCouponsRow extends StatelessWidget {
  const OfferCouponsRow({
    super.key,
    this.coupons = const [],
    this.isLoading = false,
    this.onOfferTap,
  });

  final List<Coupon> coupons;
  final bool isLoading;
  final ValueChanged<Coupon>? onOfferTap;

  /// Two fit the row without truncating; the rest live on the coupons screen.
  static const _maxCards = 2;

  @override
  Widget build(BuildContext context) {
    if (coupons.isEmpty) {
      if (!isLoading) return const SizedBox.shrink();
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          children: [
            Expanded(child: ShimmerBox(height: 94)),
            SizedBox(width: 8),
            Expanded(child: ShimmerBox(height: 94)),
          ],
        ),
      );
    }

    final shown = coupons.take(_maxCards).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _OfferCard(
                coupon: shown[i],
                imageAsset: i.isEven
                    ? 'assets/images/offer_gift_box.png'
                    : 'assets/images/offer_grocery_bag.png',
                icon: i.isEven
                    ? Icons.percent_rounded
                    : Icons.local_offer_rounded,
                onTap: onOfferTap,
              ),
            ),
          ],
          // A single offer should not stretch to fill the row.
          if (shown.length == 1) ...[
            const SizedBox(width: 8),
            const Spacer(),
          ],
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.coupon,
    required this.icon,
    required this.imageAsset,
    this.onTap,
  });

  final Coupon coupon;
  final IconData icon;
  final String imageAsset;
  final ValueChanged<Coupon>? onTap;

  /// Reads off the coupon itself, so the card can never promise a threshold or
  /// a discount the server would not honour.
  String get _subtitle {
    if (coupon.minOrderValue > 0) {
      return 'On orders above ${coupon.minOrderValue.asCurrency}';
    }
    return switch (coupon.discountType) {
      DiscountType.percentage => '${coupon.discountValue.toInt()}% off your order',
      DiscountType.flat => '${coupon.discountValue.asCurrency} off your order',
    };
  }

  String get _title =>
      coupon.title.trim().isNotEmpty ? coupon.title.trim() : coupon.code;

  @override
  Widget build(BuildContext context) {
    const cardColor = Color(0xFFF6F4ED);

    return GestureDetector(
      onTap: onTap == null ? null : () => onTap!(coupon),
      child: Container(
        height: 94,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFDE68A), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 50, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFF43B5A8),
                      // color: Color(0xFFFFC107),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 14, color: const Color(0xFF1F2937)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall!.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: const Color(0xFF1F2937),
                      height: 1.1,
                    ),
                  ),
                  Text(
                    _subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall!.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 9.5,
                      color: const Color(0xFF6B7280),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: context.text.labelSmall!.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          color: const Color(0xFFD97706),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 10,
                        color: Color(0xFFD97706),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              right: 2,
              bottom: 2,
              top: 10,
              width: 58,
              child: Image.asset(
                imageAsset,
                fit: BoxFit.contain,
                alignment: Alignment.bottomRight,
                colorBlendMode: BlendMode.darken,
                color: cardColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
