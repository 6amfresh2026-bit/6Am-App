import 'json_reader.dart';

/// From `GET /food/search/categories/admin` (and the public category list,
/// which uses the same serializer).
class CategoryDto {
  const CategoryDto({
    required this.id,
    required this.name,
    this.image = '',
    this.sortOrder = 0,
    this.foodTypeScope = '',
    this.isActive = true,
  });

  final String id;
  final String name;
  final String image;
  final int sortOrder;
  final String foodTypeScope;
  final bool isActive;

  factory CategoryDto.fromJson(Map<String, dynamic> json) => CategoryDto(
        id: json.id(),
        name: json.str('name'),
        image: json.imageUrl('image'),
        sortOrder: json.integer('sortOrder'),
        foodTypeScope: json.str('foodTypeScope'),
        isActive: json.boolean('isActive', true),
      );
}
