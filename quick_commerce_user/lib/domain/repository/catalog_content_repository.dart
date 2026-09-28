import '../model/banner.dart';
import '../model/cms_page.dart';

/// Home-screen merchandising content (banners, promo strips) from the
/// backend's landing module.
abstract interface class CatalogContentRepository {
  Future<List<PromoBanner>> heroBanners();

  Future<List<PromoBanner>> topBanners();

  Future<List<PromoBanner>> promotionBanners();

  /// A CMS page (`terms`, `privacy`, `about`, …). Null when the admin has not
  /// published that key yet.
  Future<CmsPage?> page(String key);

  /// Free-delivery threshold and fee configuration, used for the cart's
  /// "add ₹X more for free delivery" nudge.
  Future<({double freeDeliveryThreshold, double baseDeliveryFee})> feeSettings();
}
