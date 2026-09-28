import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_user/domain/service/grocery_list_parser.dart';

void main() {
  group('GroceryListParser', () {
    test('strips bullets, quantities and units to bare product names', () {
      const raw = '''
- 2x Amul Milk
1 kg Onion
• Toor Dal 500g
Bread
Eggs (6)
''';
      expect(
        GroceryListParser.parse(raw),
        ['Amul Milk', 'Onion', 'Toor Dal', 'Bread', 'Eggs'],
      );
    });

    test('drops blanks, numbers-only and one-char noise', () {
      expect(GroceryListParser.parse('\n\n12\n-\nX\n  \n'), isEmpty);
    });

    test('de-duplicates case-insensitively, keeping first occurrence', () {
      expect(
        GroceryListParser.parse('Milk\nmilk\nMILK\nCurd'),
        ['Milk', 'Curd'],
      );
    });

    test('keeps a leading number that is part of the name', () {
      // "2% Milk" must not lose its "2%" — only quantity+space is stripped.
      expect(GroceryListParser.parse('2% Milk'), ['2% Milk']);
    });
  });
}
