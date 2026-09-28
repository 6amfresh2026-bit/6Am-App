/// A selectable pack/size of a product. `otherPrice` is the backend's
/// compare-at (strike-through) price.
class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.name,
    required this.price,
    this.comparePrice,
  });

  final String id;
  final String name;
  final double price;
  final double? comparePrice;

  bool get isDiscounted => comparePrice != null && comparePrice! > price;

  int get discountPercent => isDiscounted
      ? (((comparePrice! - price) / comparePrice!) * 100).round()
      : 0;

  @override
  bool operator ==(Object other) =>
      other is ProductVariant && other.id == id && other.price == price;

  @override
  int get hashCode => Object.hash(id, price);
}
