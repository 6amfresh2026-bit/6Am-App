import 'product.dart';
import 'seller.dart';

/// Everything the customer has saved, from one `GET /food/user/favorites`.
///
/// The ids and the objects deliberately do not match up:
///
/// * [productIds] is every product ever wishlisted, including ones since
///   delisted. Hearts bind to this, so a heart the customer tapped stays
///   filled even after the product stops being sold.
/// * [products] is only what is still orderable, and is what the wishlist
///   screen renders.
///
/// So `productIds.length >= products.length`, and building heart state from
/// [products] would make hearts un-fill on their own. The same split applies
/// to [storeIds] and [stores].
class Wishlist {
  const Wishlist({
    this.productIds = const {},
    this.storeIds = const {},
    this.products = const [],
    this.stores = const [],
  });

  static const empty = Wishlist();

  final Set<String> productIds;
  final Set<String> storeIds;
  final List<Product> products;
  final List<Seller> stores;

  bool get isEmpty => products.isEmpty && stores.isEmpty;

  bool hasProduct(String productId) => productIds.contains(productId);

  bool hasStore(String storeId) => storeIds.contains(storeId);

  /// Counts come from the rendered lists, not the id sets — "12 saved" above a
  /// screen showing 9 cards is a bug report waiting to happen.
  int get productCount => products.length;

  int get storeCount => stores.length;

  /// Applies a toggle locally so every heart updates without a refetch. The
  /// product list is pruned on removal but never grown on add: the card needs
  /// catalogue fields this call does not carry, so it arrives on the next load.
  Wishlist withProduct(String productId, {required bool saved}) {
    final ids = {...productIds};
    if (saved) {
      ids.add(productId);
    } else {
      ids.remove(productId);
    }
    return Wishlist(
      productIds: ids,
      storeIds: storeIds,
      products:
          saved ? products : products.where((p) => p.id != productId).toList(),
      stores: stores,
    );
  }

  Wishlist withStore(String storeId, {required bool saved}) {
    final ids = {...storeIds};
    if (saved) {
      ids.add(storeId);
    } else {
      ids.remove(storeId);
    }
    return Wishlist(
      productIds: productIds,
      storeIds: ids,
      products: products,
      stores: saved ? stores : stores.where((s) => s.id != storeId).toList(),
    );
  }
}
