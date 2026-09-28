import '../../domain/model/coupon.dart';
import '../dto/coupon_dto.dart';

abstract final class CouponMapper {
  static Coupon toDomain(CouponDto dto) => Coupon(
        id: dto.id.isEmpty ? dto.code : dto.id,
        code: dto.code,
        title: dto.title,
        discountType: dto.discountType.toLowerCase().contains('percent')
            ? DiscountType.percentage
            : DiscountType.flat,
        discountValue: dto.discountValue,
        minOrderValue: dto.minOrderValue,
        maxDiscount: dto.maxDiscount,
        sellerId: dto.restaurantId,
        sellerName: dto.restaurantName,
        isFirstOrderOnly: dto.isFirstOrderOnly,
        expiresAt: dto.endDate,
      );

  static List<Coupon> toDomainList(List<CouponDto> dtos) => dtos
      .where((d) => d.code.trim().isNotEmpty)
      .map(toDomain)
      .where((c) => !c.isExpired)
      .toList();
}
