import 'json_reader.dart';

/// One saved line of a monthly list. `name` is the backend's save-time
/// snapshot of the product name — it is not re-resolved on read.
class MonthlyListItemDto {
  const MonthlyListItemDto({
    required this.itemId,
    required this.quantity,
    this.variantId = '',
    this.name = '',
  });

  final String itemId;
  final int quantity;
  final String variantId;
  final String name;

  factory MonthlyListItemDto.fromJson(Map<String, dynamic> json) =>
      MonthlyListItemDto(
        // `itemId` is a raw ObjectId here, but arrives populated on some
        // responses — `id()` handles both shapes.
        itemId: json.id(const ['itemId', 'item', '_id']),
        quantity: json.integer('quantity', 1),
        variantId: json.str('variantId'),
        name: json.str('name'),
      );
}

class MonthlyListDto {
  const MonthlyListDto({
    required this.id,
    required this.name,
    required this.restaurantId,
    required this.items,
    this.restaurantName = '',
    this.isActive = true,
    this.lastOrderedAt,
    this.lastOrderId = '',
    this.createdAt,
  });

  final String id;
  final String name;
  final String restaurantId;
  final String restaurantName;
  final List<MonthlyListItemDto> items;
  final bool isActive;
  final DateTime? lastOrderedAt;
  final String lastOrderId;
  final DateTime? createdAt;

  factory MonthlyListDto.fromJson(Map<String, dynamic> json) {
    // `restaurantId` is normally a bare id, but a populated response carries
    // the name too — worth keeping when it is there.
    final restaurant = json.mapOrNull('restaurantId');

    return MonthlyListDto(
      id: json.id(),
      name: json.str('name', 'My Monthly List'),
      restaurantId: json.id(const ['restaurantId']),
      restaurantName: restaurant?.firstStr(const ['name', 'restaurantName']) ?? '',
      items: json.objects('items').map(MonthlyListItemDto.fromJson).toList(),
      isActive: json.boolean('isActive', true),
      lastOrderedAt: json.dateOrNull('lastOrderedAt'),
      lastOrderId: json.id(const ['lastOrderId']),
      createdAt: json.dateOrNull('createdAt'),
    );
  }
}
