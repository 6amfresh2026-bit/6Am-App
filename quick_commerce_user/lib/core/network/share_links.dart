import 'media_url.dart';

/// Public, shareable https links to backend-rendered pages.
///
/// These must be https and must point at the backend, not at a custom scheme:
/// `modules/food/public/shareLinks.routes.js` serves each of these paths with
/// Open Graph tags, which is what makes WhatsApp/Instagram render a preview
/// card. A `suvio://` or `appzeto://` string pastes as dead text — no preview,
/// not even tappable — and nothing in the app registers those schemes anyway.
///
/// The host is the API origin, which [MediaUrl] already derives from
/// `AppConfig.apiBaseUrl` at startup.
abstract final class ShareLinks {
  /// `GET /food-detail?id=…&restaurantId=…`
  static String product({required String productId, String sellerId = ''}) {
    final query = Uri(
      queryParameters: {
        'id': productId,
        if (sellerId.isNotEmpty) 'restaurantId': sellerId,
      },
    ).query;
    return MediaUrl.resolve('/food-detail?$query');
  }

  /// `GET /restaurant-detail/:id`
  static String seller(String sellerId) =>
      MediaUrl.resolve('/restaurant-detail/$sellerId');
}
