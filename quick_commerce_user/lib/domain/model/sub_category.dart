/// A second-level grouping inside a category.
///
/// The backend's category tree is flat, so sub-categories are derived in the
/// domain layer from the distinct brands/pack-sizes present in a category's
/// items (see `CatalogGroupingService`). Flagged in the README's Backend Gaps.
class SubCategory {
  const SubCategory({
    required this.id,
    required this.name,
    required this.parentCategoryId,
    this.imageUrl = '',
    this.itemCount = 0,
  });

  final String id;
  final String name;
  final String parentCategoryId;
  final String imageUrl;
  final int itemCount;

  @override
  bool operator ==(Object other) => other is SubCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
