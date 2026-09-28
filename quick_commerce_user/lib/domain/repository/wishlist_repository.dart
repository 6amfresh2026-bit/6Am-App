import '../model/wishlist.dart';

/// Backed by the backend's favourites endpoints, which hold saved products and
/// saved stores in one collection.
abstract interface class WishlistRepository {
  /// The whole list — ids and objects, products and stores — in a single call.
  /// One request fills every heart in the app and both wishlist tabs.
  Future<Wishlist> snapshot();

  /// Saves or removes a product. Both directions are idempotent server-side,
  /// so a retry after a dropped response is safe and taps need no debounce.
  /// Returns the resulting saved state as the server reports it.
  Future<bool> setProductSaved(String productId, {required bool saved});

  Future<bool> setStoreSaved(String storeId, {required bool saved});
}
