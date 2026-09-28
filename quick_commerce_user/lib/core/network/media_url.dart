/// Resolves the media paths the backend stores.
///
/// Uploads are persisted as root-relative paths (`/uploads/food/...`) because
/// the web frontend resolves them against its own origin through nginx. A
/// mobile client has no origin of its own, so `Image.network('/uploads/...')`
/// fails outright. Every image field routes through here to be made absolute
/// against the API host.
abstract final class MediaUrl {
  static String _origin = '';

  /// Called once at startup with `AppConfig.apiBaseUrl` (…/api/v1); the origin
  /// is everything before the path.
  static void configure(String apiBaseUrl) {
    final uri = Uri.tryParse(apiBaseUrl);
    _origin = uri == null || !uri.hasAuthority
        ? ''
        : Uri(scheme: uri.scheme, host: uri.host, port: uri.hasPort ? uri.port : null)
            .toString();
  }

  static String resolve(String url) {
    final value = url.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    if (value.startsWith('//')) return 'https:$value';
    if (_origin.isEmpty) return value;
    return value.startsWith('/') ? '$_origin$value' : '$_origin/$value';
  }
}
