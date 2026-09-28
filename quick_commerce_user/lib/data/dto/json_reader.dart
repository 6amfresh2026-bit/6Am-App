import '../../core/network/media_url.dart';

/// Defensive readers for backend JSON.
///
/// The API is inconsistent in places (ids arrive as `id` or `_id`, numbers as
/// strings, images as a string or a `{url}` object, pagination as three
/// different envelopes), so every DTO goes through these instead of casting.
extension JsonReader on Map<String, dynamic> {
  String str(String key, [String fallback = '']) {
    final value = this[key];
    if (value == null) return fallback;
    if (value is String) return value;
    return value.toString();
  }

  /// First non-empty string among [keys].
  String firstStr(List<String> keys, [String fallback = '']) {
    for (final key in keys) {
      final value = str(key);
      if (value.trim().isNotEmpty) return value;
    }
    return fallback;
  }

  double? doubleOrNull(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  double dbl(String key, [double fallback = 0]) => doubleOrNull(key) ?? fallback;

  int? intOrNull(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  int integer(String key, [int fallback = 0]) => intOrNull(key) ?? fallback;

  bool boolean(String key, [bool fallback = false]) {
    final value = this[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.toLowerCase().trim();
      if (v == 'true' || v == '1' || v == 'yes') return true;
      if (v == 'false' || v == '0' || v == 'no') return false;
    }
    return fallback;
  }

  DateTime? dateOrNull(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt()).toLocal();
    }
    return null;
  }

  DateTime date(String key) => dateOrNull(key) ?? DateTime.now();

  Map<String, dynamic>? mapOrNull(String key) {
    final value = this[key];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  Map<String, dynamic> mapAt(String key) => mapOrNull(key) ?? const {};

  List<Map<String, dynamic>> objects(String key) {
    final value = this[key];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<String> strings(String key) {
    final value = this[key];
    if (value is! List) return const [];
    return value
        .map((e) => e is String ? e : (e is Map ? (e['url'] ?? '').toString() : ''))
        .where((s) => s.trim().isNotEmpty)
        .cast<String>()
        .toList();
  }

  /// Mongo ids arrive as `id`, `_id`, or a populated `{_id: ...}` object.
  String id([List<String> keys = const ['id', '_id']]) {
    for (final key in keys) {
      final value = this[key];
      if (value is String && value.trim().isNotEmpty) return value;
      if (value is Map && value['_id'] != null) return value['_id'].toString();
    }
    return '';
  }

  /// Images are sometimes a plain URL string, sometimes `{url, publicId}`, and
  /// are stored root-relative — `MediaUrl` makes them absolute.
  String imageUrl(String key) {
    final value = this[key];
    if (value is String) return MediaUrl.resolve(value);
    if (value is Map) return MediaUrl.resolve((value['url'] ?? '').toString());
    return '';
  }
}

/// Blank strings are how the backend spells "absent" for optional text, so
/// callers that need a real null (a nullable model field, an omitted request
/// key) funnel through this rather than each writing the same ternary.
extension NullableString on String {
  String? get nullIfEmpty => trim().isEmpty ? null : this;
}

/// Pagination arrives flat (`total/page/limit`), nested (`pagination`/`meta`),
/// or not at all. Normalised here so mappers do not each reinvent it.
class PageMeta {
  const PageMeta({required this.total, required this.page, required this.pageSize});

  final int total;
  final int page;
  final int pageSize;

  static const unknown = PageMeta(total: -1, page: 1, pageSize: -1);

  factory PageMeta.from(Map<String, dynamic> json, {int fallbackCount = 0}) {
    final nested = json.mapOrNull('pagination') ?? json.mapOrNull('meta');
    if (nested != null) {
      return PageMeta(
        total: nested.integer('total', fallbackCount),
        page: nested.integer('page', 1),
        pageSize: nested.integer('limit', fallbackCount),
      );
    }
    if (json.containsKey('page') || json.containsKey('limit')) {
      return PageMeta(
        total: json.integer('total', fallbackCount),
        page: json.integer('page', 1),
        pageSize: json.integer('limit', fallbackCount),
      );
    }
    return PageMeta(total: json.integer('total', fallbackCount), page: 1, pageSize: -1);
  }
}
