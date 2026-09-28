import 'product.dart';

/// A seller/store fulfilling catalog items, derived from backend product catalog data.
class Seller {
  const Seller({
    required this.id,
    required this.name,
    this.imageUrl = '',
    this.acceptingOrders = true,
    this.deliveryMinutes,
    this.productCount = 1,
    this.rating = 0,
    this.ratingCount = 0,
    this.products = const [],
    this.isVerified = true,
    this.distanceKm,
    this.locality = '',
    this.tags = const [],
    this.minOrderPrice,
    this.discountText = '',
    this.highlights = const [],
  });

  final String id;
  final String name;
  final String imageUrl;
  final bool acceptingOrders;

  /// Real delivery estimate; null when the catalogue does not carry one.
  final int? deliveryMinutes;
  final int productCount;

  /// Averaged from the seller's rated products; 0 when none are rated. Never a
  /// placeholder — the card hides the stars when this is 0.
  final double rating;
  final int ratingCount;
  final List<Product> products;
  final bool isVerified;
  final double? distanceKm;
  final String locality;
  final List<String> tags;
  final double? minOrderPrice;
  final String discountText;
  final List<String> highlights;

  bool get isOpen => acceptingOrders;
  bool get hasRating => rating > 0;

  /// Images of all actual products belonging to this seller.
  List<String> get productImages {
    final list = <String>[];
    for (final p in products) {
      if (p.imageUrl.trim().isNotEmpty) {
        list.add(p.imageUrl.trim());
      }
      for (final img in p.images) {
        if (img.trim().isNotEmpty) {
          list.add(img.trim());
        }
      }
    }
    if (imageUrl.trim().isNotEmpty) {
      list.add(imageUrl.trim());
    }
    final seen = <String>{};
    return list.where(seen.add).toList();
  }

  String get formattedRatingCount {
    if (ratingCount >= 1000) {
      return '${(ratingCount / 1000).toStringAsFixed(1)}K+';
    }
    return '$ratingCount';
  }

  @override
  bool operator ==(Object other) => other is Seller && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
