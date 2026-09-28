/// A catalog category. Sourced from the admin-curated category list.
class Category {
  const Category({
    required this.id,
    required this.name,
    this.imageUrl = '',
    this.sortOrder = 0,
    this.foodTypeScope = '',
    this.itemCount = 0,
  });

  final String id;
  final String name;
  final String imageUrl;
  final int sortOrder;
  final String foodTypeScope;
  final int itemCount;

  @override
  bool operator ==(Object other) => other is Category && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
