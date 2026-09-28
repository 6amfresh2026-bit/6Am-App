import 'json_reader.dart';

/// From `GET /food/restaurant/restaurants/:id/addons`.
class AddonDto {
  const AddonDto({
    required this.id,
    required this.name,
    required this.price,
    this.description = '',
    this.isVeg = true,
    this.image = '',
    this.groupName = '',
  });

  final String id;
  final String name;
  final double price;
  final String description;
  final bool isVeg;
  final String image;
  final String groupName;

  factory AddonDto.fromJson(Map<String, dynamic> json) => AddonDto(
        id: json.id(),
        name: json.str('name'),
        price: json.dbl('price'),
        description: json.str('description'),
        isVeg: json.boolean('isVeg', true),
        image: json.imageUrl('image'),
        groupName: json.mapAt('group').str('name'),
      );
}

class AddonGroupDto {
  const AddonGroupDto({
    required this.name,
    required this.options,
    this.minSelect = 0,
    this.maxSelect = 0,
    this.selectionLabel = '',
  });

  final String name;
  final List<AddonDto> options;
  final int minSelect;
  final int maxSelect;
  final String selectionLabel;

  factory AddonGroupDto.fromJson(Map<String, dynamic> json) => AddonGroupDto(
        name: json.firstStr(['name', 'title']),
        options: json.objects('options').map(AddonDto.fromJson).toList(),
        minSelect: json.integer('minSelect'),
        maxSelect: json.integer('maxSelect'),
        selectionLabel: json.str('selectionLabel'),
      );
}
