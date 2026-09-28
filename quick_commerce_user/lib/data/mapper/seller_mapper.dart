import '../../domain/model/seller.dart';
import '../dto/product_dto.dart';

abstract final class SellerMapper {
  /// A store as the favourites endpoint returns it.
  ///
  /// That payload carries no products, so `productCount` stays at zero rather
  /// than the `Seller` default of one — a saved-store card must not claim an
  /// item it has not loaded.
  static Seller toDomain(SellerDto dto) => Seller(
        id: dto.id,
        name: dto.name,
        imageUrl: dto.image,
        acceptingOrders: dto.isAcceptingOrders,
        deliveryMinutes: dto.deliveryMinutes,
        productCount: 0,
        rating: dto.rating,
        ratingCount: dto.ratingCount,
      );

  static List<Seller> toDomainList(List<SellerDto> dtos) =>
      dtos.map(toDomain).toList();
}
