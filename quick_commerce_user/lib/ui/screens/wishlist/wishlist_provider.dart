import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di/app_providers.dart';
import '../../../domain/model/product.dart';
import '../../../domain/model/seller.dart';

/// Saved products, straight from the wishlist snapshot the app already holds.
///
/// This used to issue its own `GET /favorites`, so opening the screen fetched
/// the same payload twice — once for hearts, once for cards. One call now
/// fills both.
final wishlistProductsProvider = Provider<List<Product>>(
  (ref) => ref.watch(wishlistProvider).valueOrNull?.products ?? const [],
);

final wishlistStoresProvider = Provider<List<Seller>>(
  (ref) => ref.watch(wishlistProvider).valueOrNull?.stores ?? const [],
);
