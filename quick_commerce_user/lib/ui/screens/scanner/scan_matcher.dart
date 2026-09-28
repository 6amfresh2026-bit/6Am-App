import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di/repository_providers.dart';
import '../../../domain/model/product.dart';
import '../../../domain/repository/product_repository.dart';

/// Result of matching a scanned grocery list against the live catalogue.
class GroceryMatchResult {
  const GroceryMatchResult({required this.found, required this.notFound});

  /// Unique, available products to add to the cart.
  final List<Product> found;

  /// List item names that had no catalogue match.
  final List<String> notFound;
}

/// A search term read off a scanned photo (a barcode value, a line of text, or
/// an image label) together with how much to trust it (0..1).
class ScanCandidate {
  const ScanCandidate(this.term, this.confidence);
  final String term;
  final double confidence;
}

/// A catalogue product a scan resolved to, with the confidence carried from the
/// signal that found it. [needsConfirmation] is true when the match is too weak
/// to add without the user's say-so.
class DetectedProduct {
  const DetectedProduct({
    required this.product,
    required this.confidence,
    required this.term,
  });

  final Product product;
  final double confidence;
  final String term;

  /// Below this the match is shown for confirmation instead of auto-added.
  static const double confidentThreshold = 0.75;

  bool get needsConfirmation => confidence < confidentThreshold;
}

/// Looks scanned values up in the real product catalogue.
///
/// Both a single barcode/QR value and each grocery-list line are resolved the
/// same way: through `/food/search/products` (`ProductRepository.search`). The
/// backend stores no barcode field, so a raw numeric barcode simply finds
/// nothing and the caller reports "not available" — nothing here is mocked.
class ScanMatcher {
  const ScanMatcher(this._repo);

  final ProductRepository _repo;

  /// Resolves a single scanned value to the best available catalogue match,
  /// or null when nothing matches.
  Future<Product?> productForScan(String code) async {
    final q = code.trim();
    if (q.isEmpty) return null;
    final page = await _repo.search(query: q, pageSize: 5);
    return _best(page.items);
  }

  /// Matches every parsed list name against the catalogue. Searches run
  /// concurrently; results keep the original list order for the summary.
  /// A name that resolves to an already-matched product is dropped so the same
  /// product is never added twice.
  Future<GroceryMatchResult> matchGroceryList(List<String> names) async {
    final matches = await Future.wait(
      names.map((n) => _repo.search(query: n, pageSize: 5).then(
            (page) => _best(page.items),
            onError: (_) => null,
          )),
    );

    final found = <Product>[];
    final foundIds = <String>{};
    final notFound = <String>[];
    for (var i = 0; i < names.length; i++) {
      final match = matches[i];
      if (match == null) {
        notFound.add(names[i]);
      } else if (foundIds.add(match.id)) {
        found.add(match);
      }
    }
    return GroceryMatchResult(found: found, notFound: notFound);
  }

  /// Resolves image/barcode/text signals to catalogue products.
  ///
  /// Each candidate is searched; a hit keeps the candidate's confidence, dialled
  /// down when the product name doesn't actually share a word with the term —
  /// this is what stops a generic label like "bottle" from silently adding an
  /// unrelated product. Duplicates collapse to the highest-confidence hit and
  /// results come back most-confident first.
  Future<List<DetectedProduct>> matchDetections(
    List<ScanCandidate> candidates,
  ) async {
    final products = await Future.wait(
      candidates.map((c) => _repo.search(query: c.term, pageSize: 5).then(
            (page) => _best(page.items),
            onError: (_) => null,
          )),
    );

    final byId = <String, DetectedProduct>{};
    for (var i = 0; i < candidates.length; i++) {
      final product = products[i];
      if (product == null) continue;
      final c = candidates[i];
      final confidence =
          _related(c.term, product.name) ? c.confidence : c.confidence * 0.6;
      final existing = byId[product.id];
      if (existing == null || confidence > existing.confidence) {
        byId[product.id] = DetectedProduct(
          product: product,
          confidence: confidence,
          term: c.term,
        );
      }
    }

    return byId.values.toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
  }

  /// True when the term and the product name share a meaningful word — a cheap
  /// guard against the backend returning a loosely-related product.
  static bool _related(String term, String name) {
    final n = name.toLowerCase();
    for (final word in term.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
      if (word.length >= 3 && n.contains(word)) return true;
    }
    return false;
  }

  Product? _best(List<Product> items) {
    if (items.isEmpty) return null;
    for (final p in items) {
      if (p.isPurchasable) return p;
    }
    return items.first;
  }
}

final scanMatcherProvider = Provider<ScanMatcher>(
  (ref) => ScanMatcher(ref.watch(productRepositoryProvider)),
);
