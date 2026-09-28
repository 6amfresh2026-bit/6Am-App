import '../utils/currency_formatter.dart';

extension NumFormatting on num {
  String get asCurrency => CurrencyFormatter.format(this);
  String get asCurrencyPrecise =>
      CurrencyFormatter.format(this, decimals: true);

  /// Percentage saved when [this] is the selling price and [mrp] the strike price.
  int discountPercentFrom(num? mrp) {
    if (mrp == null || mrp <= 0 || mrp <= this) return 0;
    return (((mrp - this) / mrp) * 100).round();
  }
}

extension DurationFormatting on int {
  /// A delivery promise in words. The backend derives this from the real
  /// distance between store and drop, so an address far outside the serving
  /// area produces a genuinely large number — "3712 mins" is unreadable, and
  /// reading "62 hrs" is what tells the customer something is wrong.
  String get asDurationLabel {
    if (this < 60) return '$this mins';
    final hours = this ~/ 60;
    final minutes = this % 60;
    if (hours < 24) {
      return minutes == 0 ? '$hours hr' : '$hours hr $minutes mins';
    }
    final days = hours ~/ 24;
    final remainingHours = hours % 24;
    return remainingHours == 0 ? '$days days' : '$days days $remainingHours hr';
  }
}

extension DoubleRounding on double {
  double roundTo(int places) {
    final f = [1, 10, 100, 1000][places.clamp(0, 3)];
    return (this * f).round() / f;
  }
}
