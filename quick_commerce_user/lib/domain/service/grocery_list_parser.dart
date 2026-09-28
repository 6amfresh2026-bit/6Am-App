/// Turns the raw text an OCR pass reads off a photographed grocery list into a
/// clean, de-duplicated set of item names ready to search the catalogue with.
///
/// The recognizer hands us lines like `- 2x Amul Milk`, `1 kg Onion` or
/// `• Toor Dal 500g`. Backend search matches on the product name, so the
/// quantities, bullets and units are noise that has to come off first.
///
/// ponytail: heuristic cleanup — strips leading bullets/quantities and trailing
/// parenthetical/unit amounts. It deliberately does not try to understand
/// quantities (a list is a shopping intent, not an order); each matched product
/// is added once. Upgrade to per-item quantity only if users ask for it.
abstract final class GroceryListParser {
  // Leading list markers: -, *, •, ▢, checkboxes, "1." / "1)" ordinals.
  static final _bullet = RegExp(r'^\s*(?:[-*•▢☐✓✔]|\[.?\]|\d+[.)])\s*');

  // A leading quantity: "2", "2x", "2 x", "1 kg", "500 g", "2 packs", "1L".
  static final _leadingQty = RegExp(
    r'^\s*\d+\s*(?:x|kg|kgs|g|gm|gms|gram|grams|ml|l|ltr|litre|liter|pc|pcs|pack|packs|packet|packets|dozen|nos?)?\s+',
    caseSensitive: false,
  );

  // A trailing quantity/unit chunk: "500g", "(6)", "x2", "- 2 packs".
  static final _trailingQty = RegExp(
    r'\s*[-–]?\s*(?:\(.*?\)|x?\s*\d+\s*(?:x|kg|kgs|g|gm|gms|ml|l|ltr|litre|liter|pc|pcs|pack|packs|packet|packets|dozen|nos?)?)\s*$',
    caseSensitive: false,
  );

  static final _spaces = RegExp(r'\s+');

  /// Parses the full recognized text block into ordered, unique item names.
  static List<String> parse(String rawText) {
    final seen = <String>{};
    final items = <String>[];
    for (final line in rawText.split('\n')) {
      final name = _clean(line);
      if (name == null) continue;
      final key = name.toLowerCase();
      if (seen.add(key)) items.add(name);
    }
    return items;
  }

  /// Cleans one line to a searchable name, or null if it is not an item
  /// (blank, a heading, or pure quantity/number).
  static String? _clean(String line) {
    var s = line.replaceAll(_bullet, '');
    s = s.replaceAll(_leadingQty, '');
    s = s.replaceAll(_trailingQty, '');
    s = s.replaceAll(_spaces, ' ').trim();

    // Drop leftovers that aren't a real product name to search.
    if (s.length < 2) return null;
    if (RegExp(r'^[\d\W]+$').hasMatch(s)) return null; // digits/punctuation only
    return s;
  }
}
