import '../../core/network/api_client.dart';
import '../../domain/model/wishlist.dart';
import '../../domain/repository/wishlist_repository.dart';
import '../dto/json_reader.dart';
import '../dto/product_dto.dart';
import '../mapper/product_mapper.dart';
import '../mapper/seller_mapper.dart';
import 'api_paths.dart';

class ApiWishlistRepository implements WishlistRepository {
  ApiWishlistRepository(this._client);

  final ApiClient _client;

  @override
  Future<Wishlist> snapshot() async {
    final json = await _client.get(ApiPaths.favorites, requiresAuth: true);
    if (json is! Map<String, dynamic>) return Wishlist.empty;

    // One response feeds everything: the id sets drive every heart in the app,
    // the object lists render the two wishlist tabs. Reading them separately
    // would mean two round trips for data that always arrives together.
    return Wishlist(
      productIds: json.strings('foodIds').toSet(),
      storeIds: json.strings('restaurantIds').toSet(),
      products: ProductMapper.toDomainList(
        json.objects('foods').map(ProductDto.fromJson).toList(),
      ),
      stores: SellerMapper.toDomainList(
        json.objects('restaurants').map(SellerDto.fromJson).toList(),
      ),
    );
  }

  @override
  Future<bool> setProductSaved(String productId, {required bool saved}) =>
      _setSaved(ApiPaths.favoriteFood(productId), saved: saved);

  @override
  Future<bool> setStoreSaved(String storeId, {required bool saved}) =>
      _setSaved(ApiPaths.favoriteRestaurant(storeId), saved: saved);

  /// POST saves, DELETE removes; both answer `{favorited}` and both are
  /// idempotent, so repeating either is harmless.
  Future<bool> _setSaved(String path, {required bool saved}) async {
    final json = saved
        ? await _client.post(path, requiresAuth: true)
        : await _client.delete(path, requiresAuth: true);

    if (json is! Map<String, dynamic>) return saved;
    return json.boolean('favorited', saved);
  }
}
