import 'addon.dart';
import 'product.dart';
import 'product_variant.dart';

/// One line in the cart: a product, optionally a chosen variant, plus add-ons.
///
/// Identity is (product, variant, add-on set) — adding the same product with a
/// different add-on selection creates a separate line, which is what the
/// backend's `lineItemId` expects.
class CartItem {
  const CartItem({
    required this.product,
    required this.quantity,
    this.variant,
    this.addons = const [],
    this.note = '',
  });

  final Product product;
  final int quantity;
  final ProductVariant? variant;
  final List<Addon> addons;
  final String note;

  String get lineId {
    final addonIds = addons.map((a) => a.id).toList()..sort();
    return [product.id, variant?.id ?? '', addonIds.join('+')].join('|');
  }

  double get unitPrice => variant?.price ?? product.price;

  double get addonsPrice =>
      addons.fold(0, (sum, addon) => sum + addon.price);

  double get lineTotal => (unitPrice + addonsPrice) * quantity;

  double? get unitStrikePrice {
    final v = variant;
    if (v != null) return v.isDiscounted ? v.comparePrice : null;
    return product.strikePrice;
  }

  /// MRP-side total, used for the "you saved" callout.
  double get lineStrikeTotal =>
      ((unitStrikePrice ?? unitPrice) + addonsPrice) * quantity;

  String get variantLabel => variant?.name ?? product.unitLabel;

  String get addonSummary => addons.map((a) => a.name).join(', ');

  CartItem copyWith({int? quantity, List<Addon>? addons, String? note}) => CartItem(
        product: product,
        quantity: quantity ?? this.quantity,
        variant: variant,
        addons: addons ?? this.addons,
        note: note ?? this.note,
      );

  @override
  bool operator ==(Object other) => other is CartItem && other.lineId == lineId;

  @override
  int get hashCode => lineId.hashCode;
}
