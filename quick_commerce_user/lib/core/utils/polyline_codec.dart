/// Decodes Google's encoded polyline format.
///
/// The backend's `GET /orders/:id/route` returns a route as an encoded
/// polyline string; this turns it back into points for the map. Pure Dart with
/// no dependency, because the one function is smaller than the package.
abstract final class PolylineCodec {
  /// Returns `(latitude, longitude)` pairs. Malformed input yields an empty
  /// list rather than throwing — a broken route must not take down tracking.
  static List<(double lat, double lng)> decode(String encoded) {
    if (encoded.isEmpty) return const [];

    final points = <(double, double)>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    try {
      while (index < encoded.length) {
        lat += _nextDelta(encoded, index, (i) => index = i);
        lng += _nextDelta(encoded, index, (i) => index = i);
        points.add((lat / 1e5, lng / 1e5));
      }
    } on RangeError {
      return points;
    }
    return points;
  }

  /// Reads one zig-zag-encoded varint, reporting the new cursor position.
  static int _nextDelta(String encoded, int start, void Function(int) setIndex) {
    var index = start;
    var shift = 0;
    var result = 0;
    int byte;

    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1F) << shift;
      shift += 5;
    } while (byte >= 0x20);

    setIndex(index);
    return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
  }
}
