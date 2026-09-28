extension StringX on String {
  String get capitalizedWords => split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');

  String get initials {
    final words = trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return (words.first[0] + words.last[0]).toUpperCase();
  }

  String truncate(int max) => length <= max ? this : '${substring(0, max)}…';

  String? get nullIfBlank => trim().isEmpty ? null : this;
}

extension NullableStringX on String? {
  bool get isBlank => this == null || this!.trim().isEmpty;
  String orEmpty() => this ?? '';
}
