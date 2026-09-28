import '../../core/network/api_client.dart';
import '../../core/utils/logger.dart';
import '../../domain/model/banner.dart';
import '../../domain/model/cms_page.dart';
import '../../domain/repository/catalog_content_repository.dart';
import '../dto/banner_dto.dart';
import '../dto/json_reader.dart';
import '../mapper/banner_mapper.dart';
import 'api_paths.dart';

class ApiCatalogContentRepository implements CatalogContentRepository {
  ApiCatalogContentRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<PromoBanner>> heroBanners() => _banners(ApiPaths.heroBanners);

  @override
  Future<List<PromoBanner>> topBanners() => _banners(ApiPaths.topBanners);

  @override
  Future<List<PromoBanner>> promotionBanners() =>
      _banners(ApiPaths.promotionBanners);

  Future<List<PromoBanner>> _banners(String path) async {
    AppLogger.debug('GET $path', scope: 'banners');
    try {
      final json = await _client.get(path);
      if (json is! Map<String, dynamic>) {
        AppLogger.debug(
          'GET $path — unexpected payload ${json.runtimeType}',
          scope: 'banners',
        );
        return const [];
      }

      final raw = json.objects('banners');
      final banners = BannerMapper.toDomainList(
        raw.map(BannerDto.fromJson).toList(),
      );
      AppLogger.debug(
        '$path → ${raw.length} raw, ${banners.length} usable '
        '(${raw.length - banners.length} dropped for a missing image)',
        scope: 'banners',
      );
      for (final banner in banners) {
        AppLogger.debug('  ${banner.id} → ${banner.imageUrl}', scope: 'banners');
      }
      return banners;
    } catch (e, stack) {
      AppLogger.error('GET $path failed', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<CmsPage?> page(String key) async {
    final json = await _client.get(ApiPaths.page(key));
    if (json is! Map<String, dynamic>) return null;
    // `about` uses appName/description, legal keys use title/content.
    final title = json.str('title').isEmpty
        ? json.str('appName')
        : json.str('title');
    final content = json.str('content').isEmpty
        ? json.str('description')
        : json.str('content');
    final page = CmsPage(
      title: title,
      content: content,
      version: json.str('version'),
      email: json.str('email'),
      mobile: json.str('mobile'),
    );
    return page.isEmpty && page.version.isEmpty ? null : page;
  }

  @override
  Future<({double freeDeliveryThreshold, double baseDeliveryFee})>
      feeSettings() async {
    final json = await _client.get(ApiPaths.feeSettings);
    final settings =
        json is Map<String, dynamic> ? json.mapOrNull('feeSettings') : null;
    if (settings == null) {
      return (freeDeliveryThreshold: 199.0, baseDeliveryFee: 0.0);
    }

    // The fee table is distance-banded, not order-value-banded, so there is no
    // literal free-delivery threshold upstream. A zero-fee band, when one
    // exists, is the closest real signal; otherwise we fall back to the
    // configured default. Flagged in README → Backend Gaps.
    final ranges = settings.objects('deliveryFeeRanges');
    final freeBand = ranges.where((r) => r.dbl('fee') <= 0);

    return (
      freeDeliveryThreshold: freeBand.isEmpty ? 199.0 : freeBand.first.dbl('max', 199),
      baseDeliveryFee: settings.dbl('deliveryFee'),
    );
  }
}
