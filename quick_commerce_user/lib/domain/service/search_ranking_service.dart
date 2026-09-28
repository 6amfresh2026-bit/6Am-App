import '../model/product.dart';
import '../repository/product_repository.dart';

/// Client-side ranking and filtering.
///
/// The catalog endpoint accepts a query, a category and veg/stock flags but no
/// sort or price range, so those are applied here over the fetched page.
class SearchRankingService {
  const SearchRankingService();

  List<Product> apply(
    List<Product> products, {
    required ProductFilters filters,
    required ProductSort sort,
    String query = '',
  }) {
    final filtered = products.where((p) => _matches(p, filters)).toList();
    return _sorted(filtered, sort, query);
  }

  bool _matches(Product p, ProductFilters f) {
    if (f.vegOnly && !p.isVeg) return false;
    if (f.inStockOnly && !p.isPurchasable) return false;
    if (f.brand != null && p.brand.toLowerCase() != f.brand!.toLowerCase()) {
      return false;
    }
    if (f.minPrice != null && p.price < f.minPrice!) return false;
    if (f.maxPrice != null && p.price > f.maxPrice!) return false;
    if (f.minDiscountPercent != null &&
        p.discountPercent < f.minDiscountPercent!) {
      return false;
    }
    return true;
  }

  List<Product> _sorted(List<Product> items, ProductSort sort, String query) {
    final list = [...items];
    switch (sort) {
      case ProductSort.priceLowToHigh:
        list.sort((a, b) => a.price.compareTo(b.price));
      case ProductSort.priceHighToLow:
        list.sort((a, b) => b.price.compareTo(a.price));
      case ProductSort.rating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case ProductSort.discount:
        list.sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
      case ProductSort.relevance:
        list.sort((a, b) => _score(b, query).compareTo(_score(a, query)));
    }
    return list;
  }

  /// Relevance: exact prefix beats substring, in-stock beats out, and a
  /// well-rated item edges out an unrated one.
  double _score(Product p, String query) {
    final q = query.trim().toLowerCase();
    var score = 0.0;
    if (q.isNotEmpty) {
      final name = p.name.toLowerCase();
      if (name == q) {
        score += 100;
      } else if (name.startsWith(q)) {
        score += 60;
      } else if (name.contains(q)) {
        score += 30;
      }
      if (p.brand.toLowerCase().contains(q)) score += 15;
      if (p.categoryName.toLowerCase().contains(q)) score += 8;
    }
    if (p.isPurchasable) score += 20;
    score += p.rating * 2;
    if (p.isDiscounted) score += 3;
    return score;
  }

  /// Groups search results for the sectioned search screen.
  Map<String, List<Product>> groupByCategory(List<Product> products) {
    final grouped = <String, List<Product>>{};
    for (final p in products) {
      final key = p.categoryName.trim().isEmpty ? 'Other' : p.categoryName.trim();
      grouped.putIfAbsent(key, () => []).add(p);
    }
    return grouped;
  }
}
