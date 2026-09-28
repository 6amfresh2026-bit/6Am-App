import '../../domain/model/product.dart';
import '../../domain/model/product_variant.dart';
import '../dto/product_dto.dart';

abstract final class ProductMapper {
  static Product toDomain(ProductDto dto, {ProductDto? sellerFallback}) {
    final seller = dto.seller;
    final images = dto.images.where((i) => i.trim().isNotEmpty).toList();
    // No real image → empty. AppNetworkImage draws a clean fallback icon; a
    // random stock photo (the old picsum placeholder) is fake product imagery.
    final primary = dto.image.trim().isNotEmpty
        ? dto.image
        : (images.isNotEmpty ? images.first : '');

    return Product(
      id: dto.id,
      name: dto.name,
      price: dto.price,
      comparePrice: dto.otherPrice != null && dto.otherPrice! > 0
          ? dto.otherPrice
          : null,
      mrp: dto.mrp != null && dto.mrp! > 0 ? dto.mrp : null,
      description: dto.description,
      imageUrl: primary,
      images: images.isEmpty ? [primary] : images,
      categoryId: dto.categoryId,
      categoryName: dto.categoryName,
      brand: dto.brand,
      packSize: dto.packSize,
      // The backend has no boolean veg flag; veg is `foodType == 'Veg'`.
      isVeg: dto.foodType.toLowerCase().startsWith('veg'),
      isAvailable: dto.isAvailable && (dto.inStock ?? true),
      subscriptionEnabled: dto.subscriptionEnabled,
      sellerStoreType: dto.sellerStoreType,
      expiryDate: dto.expiryDate,
      stockQty: dto.stockQty,
      maxQtyPerOrder: dto.maxQtyPerOrder,
      rating: dto.rating,
      ratingCount: dto.totalRatings,
      variants: dto.variants.map(variantToDomain).toList(),
      sellerId: dto.restaurantId.isNotEmpty
          ? dto.restaurantId
          : (seller?.id ?? sellerFallback?.restaurantId ?? ''),
      sellerName: seller?.name ?? '',
      sellerImageUrl: seller?.image ?? '',
      deliveryMinutes: seller?.deliveryMinutes,
      sellerAcceptingOrders: seller?.isAcceptingOrders ?? true,
    );
  }

  static ProductVariant variantToDomain(ProductVariantDto dto) => ProductVariant(
        id: dto.id,
        name: dto.name,
        price: dto.price,
        comparePrice:
            dto.otherPrice != null && dto.otherPrice! > dto.price ? dto.otherPrice : null,
      );

  static List<Product> toDomainList(List<ProductDto> dtos) =>
      dtos.map((d) => toDomain(d)).toList();
}
