/// A product brand. Derived from the `brand` field on catalog items — the
/// backend has no brand collection (see README → Backend Gaps).
class Brand {
  const Brand({
    required this.id,
    required this.name,
    this.logoUrl = '',
    this.productCount = 0,
  });

  final String id;
  final String name;
  final String logoUrl;
  final int productCount;

  @override
  bool operator ==(Object other) => other is Brand && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
