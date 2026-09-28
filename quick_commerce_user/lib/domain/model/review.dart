/// A customer review.
///
/// The backend only stores ratings against *delivered orders*
/// (`PATCH /orders/:id/ratings`), so reviews are read back from a customer's
/// own order history rather than a per-product review collection. See the
/// README's Backend Gaps note.
class Review {
  const Review({
    required this.id,
    required this.authorName,
    required this.rating,
    required this.createdAt,
    this.comment = '',
    this.helpfulCount = 0,
  });

  final String id;
  final String authorName;
  final double rating;
  final DateTime createdAt;
  final String comment;
  final int helpfulCount;
}

/// Aggregate rating plus the 5★…1★ histogram the details screen renders.
class RatingSummary {
  const RatingSummary({
    required this.average,
    required this.total,
    required this.distribution,
  });

  final double average;
  final int total;

  /// Star value (1–5) → number of ratings.
  final Map<int, int> distribution;

  static const empty =
      RatingSummary(average: 0, total: 0, distribution: {5: 0, 4: 0, 3: 0, 2: 0, 1: 0});

  double fractionFor(int star) {
    if (total == 0) return 0;
    return (distribution[star] ?? 0) / total;
  }
}
