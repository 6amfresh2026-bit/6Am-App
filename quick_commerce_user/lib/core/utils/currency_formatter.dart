/// Indian Rupee formatting with lakh/crore grouping (12,34,567).
abstract final class CurrencyFormatter {
  static const symbol = '₹';

  static String format(num amount, {bool withSymbol = true, bool decimals = false}) {
    final negative = amount < 0;
    final value = amount.abs();
    final rounded = decimals ? value.toStringAsFixed(2) : value.round().toString();
    final parts = rounded.split('.');
    final grouped = _groupIndian(parts.first);
    final body = parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
    return '${negative ? '-' : ''}${withSymbol ? symbol : ''}$body';
  }

  static String _groupIndian(String digits) {
    if (digits.length <= 3) return digits;
    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final buffer = <String>[];
    while (rest.length > 2) {
      buffer.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) buffer.insert(0, rest);
    return '${buffer.join(',')},$last3';
  }
}
