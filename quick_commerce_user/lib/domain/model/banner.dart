/// Where a banner sends the user. Backends give us a free-text CTA link, so we
/// classify it here rather than in the widget.
enum BannerTarget { products, category, restaurant, offers, none }

class PromoBanner {
  const PromoBanner({
    required this.id,
    required this.imageUrl,
    this.videoUrl = '',
    this.title = '',
    this.ctaText = '',
    this.ctaLink = '',
    this.sortOrder = 0,
  });

  final String id;
  final String imageUrl;
  final String videoUrl;
  final String title;
  final String ctaText;
  final String ctaLink;
  final int sortOrder;

  bool get isVideo {
    if (videoUrl.trim().isNotEmpty) return true;
    final lower = imageUrl.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.m3u8') ||
        lower.contains('video');
  }

  String get mediaUrl => videoUrl.trim().isNotEmpty ? videoUrl.trim() : imageUrl.trim();

  BannerTarget get target {
    final link = ctaLink.toLowerCase();
    if (link.isEmpty) return BannerTarget.none;
    if (link.contains('offer') || link.contains('coupon')) return BannerTarget.offers;
    if (link.contains('categor')) return BannerTarget.category;
    if (link.contains('restaurant') || link.contains('store')) {
      return BannerTarget.restaurant;
    }
    return BannerTarget.products;
  }

  /// Trailing path/id segment of the CTA link, used as a listing filter.
  String get targetId {
    final segments =
        ctaLink.split(RegExp(r'[/?=&]')).where((s) => s.trim().isNotEmpty).toList();
    return segments.isEmpty ? '' : segments.last;
  }
}
