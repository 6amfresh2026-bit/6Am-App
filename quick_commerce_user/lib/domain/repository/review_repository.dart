import '../model/review.dart';

/// Reviews are read from the customer's own delivered orders — the backend has
/// no per-product review collection (README → Backend Gaps).
abstract interface class ReviewRepository {
  Future<({RatingSummary summary, List<Review> reviews})> forProduct(
    String productId,
  );

  /// Submits an item rating against a delivered order.
  Future<Review> submit({
    required String orderId,
    required String productId,
    required int rating,
    String? comment,
  });

  /// Orders the signed-in user may still rate for [productId], newest first.
  Future<List<({String orderId, String displayId, DateTime placedAt})>> rateableOrders(
    String productId,
  );
}
