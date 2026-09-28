import 'dart:convert';

import '../../core/errors/app_exception.dart';
import '../../core/local_storage/local_storage.dart';
import '../../core/network/api_client.dart';
import '../../domain/model/addon.dart';
import '../../domain/model/address.dart';
import '../../domain/model/cart.dart';
import '../../domain/model/cart_item.dart';
import '../../domain/model/product_variant.dart';
import '../../domain/repository/cart_repository.dart';
import '../dto/json_reader.dart';
import '../dto/pricing_dto.dart';
import '../dto/product_dto.dart';
import '../mapper/order_mapper.dart';
import '../mapper/pricing_mapper.dart';
import '../mapper/product_mapper.dart';
import 'api_paths.dart';

class ApiCartRepository implements CartRepository {
  ApiCartRepository(this._client, this._storage);

  final ApiClient _client;
  final LocalStorage _storage;

  @override
  Future<Cart> loadCached() async {
    final raw = _storage.getString(StorageKeys.cachedCart);
    if (raw == null || raw.isEmpty) return Cart.empty;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final items = json
          .objects('items')
          .map(_lineFromCache)
          .whereType<CartItem>()
          .toList();
      if (items.isEmpty) return Cart.empty;
      return Cart(
        items: items,
        sellerId: json.str('sellerId'),
        sellerName: json.str('sellerName'),
        deliveryMode: json.str('deliveryMode', 'basic'),
      );
    } catch (_) {
      // A corrupt cache must never wedge the app on launch.
      return Cart.empty;
    }
  }

  @override
  Future<void> cache(Cart cart) async {
    if (cart.isEmpty) {
      await _storage.remove(StorageKeys.cachedCart);
      return;
    }
    await _storage.setString(
      StorageKeys.cachedCart,
      jsonEncode({
        'sellerId': cart.sellerId,
        'sellerName': cart.sellerName,
        'deliveryMode': cart.deliveryMode,
        'items': cart.items.map(_lineToCache).toList(),
      }),
    );
  }

  @override
  Future<void> sync(Cart cart) async {
    try {
      await _client.put(
        ApiPaths.cartSync,
        body: {
          'items': cart.items.map(OrderMapper.lineToSyncJson).toList(),
          'pricing': OrderMapper.pricingToSyncJson(cart),
          'restaurantId': cart.sellerId,
          'restaurantName': cart.sellerName,
        },
        requiresAuth: true,
      );
    } on AppException {
      // Best-effort mirror: a signed-out user or a flaky network must not
      // break local cart editing.
    }
  }

  @override
  Future<({CartPricing pricing, List<PriceChange> changes, List<CartItem> items})>
      price({
    required Cart cart,
    Address? address,
    String? couponCode,
    String deliveryMode = 'basic',
    DateTime? scheduledAt,
  }) async {
    final json = await _client.post(
      ApiPaths.calculateOrder,
      body: {
        'items': cart.items.map(OrderMapper.lineToJson).toList(),
        'restaurantId': cart.sellerId,
        if (address != null) 'deliveryAddressId': address.id,
        if (address != null && address.hasCoordinates)
          'deliveryAddress': {
            'location': {
              'type': 'Point',
              'coordinates': [address.longitude, address.latitude],
            },
          },
        if (couponCode != null && couponCode.trim().isNotEmpty)
          'couponCode': couponCode.trim(),
        'deliveryMode': deliveryMode,
        if (scheduledAt != null) 'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      },
      requiresAuth: true,
    );

    if (json is! Map<String, dynamic>) {
      throw const ParseException('Unexpected pricing response.');
    }

    return (
      pricing: PricingMapper.toDomain(PricingDto.fromJson(json.mapAt('pricing'))),
      changes: json
          .objects('priceChanges')
          .map(PriceChangeDto.fromJson)
          .map(PricingMapper.changeToDomain)
          .toList(),
      items: cart.items,
    );
  }

  Map<String, dynamic> _lineToCache(CartItem item) => {
        'quantity': item.quantity,
        'note': item.note,
        'variant': item.variant == null
            ? null
            : {
                'id': item.variant!.id,
                'name': item.variant!.name,
                'price': item.variant!.price,
                'otherPrice': item.variant!.comparePrice,
              },
        'addons': item.addons
            .map((a) => {'id': a.id, 'name': a.name, 'price': a.price})
            .toList(),
        'product': {
          '_id': item.product.id,
          'name': item.product.name,
          'price': item.product.price,
          'otherPrice': item.product.comparePrice,
          'mrp': item.product.mrp,
          'image': item.product.imageUrl,
          'images': item.product.images,
          'brand': item.product.brand,
          'packSize': item.product.packSize,
          'categoryId': item.product.categoryId,
          'categoryName': item.product.categoryName,
          'foodType': item.product.isVeg ? 'Veg' : 'Non-Veg',
          'stockQty': item.product.stockQty,
          'maxQtyPerOrder': item.product.maxQtyPerOrder,
          'restaurantId': item.product.sellerId,
          'seller': {
            '_id': item.product.sellerId,
            'name': item.product.sellerName,
            'image': item.product.sellerImageUrl,
          },
        },
      };

  CartItem? _lineFromCache(Map<String, dynamic> json) {
    final productJson = json.mapOrNull('product');
    if (productJson == null) return null;

    final product = ProductMapper.toDomain(ProductDto.fromJson(productJson));
    if (product.id.isEmpty) return null;

    final variantJson = json.mapOrNull('variant');
    return CartItem(
      product: product,
      quantity: json.integer('quantity', 1),
      note: json.str('note'),
      variant: variantJson == null
          ? null
          : ProductVariant(
              id: variantJson.id(),
              name: variantJson.str('name'),
              price: variantJson.dbl('price'),
              comparePrice: variantJson.doubleOrNull('otherPrice'),
            ),
      addons: json
          .objects('addons')
          .map((a) => Addon(id: a.id(), name: a.str('name'), price: a.dbl('price')))
          .toList(),
    );
  }
}
