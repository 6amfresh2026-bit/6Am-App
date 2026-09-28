import '../../core/network/api_client.dart';
import '../../domain/model/review.dart';
import '../../domain/repository/review_repository.dart';
import '../dto/json_reader.dart';
import 'api_paths.dart';

/// Reviews are assembled from the customer's own order history.
///
/// The backend stores item ratings only inside `order.ratings.items[]` and has
/// no per-product review collection or public review feed, so this repository
/// reads what the signed-in user can actually see and writes through
/// `PATCH /orders/:orderId/ratings`. See README → Backend Gaps.
class ApiReviewRepository implements ReviewRepository {
  ApiReviewRepository(this._client);

  final ApiClient _client;

  @override
  Future<({RatingSummary summary, List<Review> reviews})> forProduct(
    String productId,
  ) async {
    final orders = await _recentOrders();
    final reviews = <Review>[];
    final distribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

    for (final order in orders) {
      for (final item in order.mapAt('ratings').objects('items')) {
        if (item.str('itemId') != productId) continue;
        final rating = item.dbl('rating');
        if (rating <= 0) continue;

        distribution[rating.round().clamp(1, 5)] =
            (distribution[rating.round().clamp(1, 5)] ?? 0) + 1;
        reviews.add(
          Review(
            id: '${order.id()}-$productId',
            authorName: order.str('customerName', 'A Suvio customer'),
            rating: rating,
            createdAt: item.dateOrNull('ratedAt') ?? order.date('createdAt'),
            comment: item.str('comment'),
          ),
        );
      }
    }

    if (reviews.isEmpty) {
      return (summary: RatingSummary.empty, reviews: const <Review>[]);
    }

    reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final total = reviews.length;
    final average =
        reviews.fold<double>(0, (sum, r) => sum + r.rating) / total;

    return (
      summary: RatingSummary(
        average: average,
        total: total,
        distribution: distribution,
      ),
      reviews: reviews,
    );
  }

  @override
  Future<Review> submit({
    required String orderId,
    required String productId,
    required int rating,
    String? comment,
  }) async {
    final json = await _client.patch(
      ApiPaths.orderRatings(orderId),
      body: {
        'restaurantRating': rating,
        'itemRatings': [
          {
            'itemId': productId,
            'rating': rating,
            if (comment != null && comment.trim().isNotEmpty)
              'comment': comment.trim(),
          }
        ],
      },
      requiresAuth: true,
    );

    final order = json is Map<String, dynamic> ? json.mapAt('order') : const <String, dynamic>{};
    return Review(
      id: '$orderId-$productId',
      authorName: order.str('customerName', 'You'),
      rating: rating.toDouble(),
      createdAt: DateTime.now(),
      comment: comment ?? '',
    );
  }

  @override
  Future<List<({String orderId, String displayId, DateTime placedAt})>>
      rateableOrders(String productId) async {
    final orders = await _recentOrders();
    final rateable = <({String orderId, String displayId, DateTime placedAt})>[];

    for (final order in orders) {
      if (order.str('orderStatus') != 'delivered') continue;

      final hasItem = order
          .objects('items')
          .any((i) => i.str('itemId') == productId);
      if (!hasItem) continue;

      final alreadyRated = order
          .mapAt('ratings')
          .objects('items')
          .any((i) => i.str('itemId') == productId);
      if (alreadyRated) continue;

      rateable.add((
        orderId: order.firstStr(['orderMongoId', '_id']),
        displayId: order.firstStr(['orderId', 'order_id']),
        placedAt: order.date('createdAt'),
      ));
    }

    rateable.sort((a, b) => b.placedAt.compareTo(a.placedAt));
    return rateable;
  }

  Future<List<Map<String, dynamic>>> _recentOrders() async {
    final json = await _client.get(
      ApiPaths.orders,
      query: {'page': 1, 'limit': 50},
      requiresAuth: true,
    );
    if (json is! Map<String, dynamic>) return const [];
    return json.objects('data');
  }
}
