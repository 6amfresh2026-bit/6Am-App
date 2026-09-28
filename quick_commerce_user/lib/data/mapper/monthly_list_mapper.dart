import '../../domain/model/monthly_list.dart';
import '../dto/monthly_list_dto.dart';

abstract final class MonthlyListMapper {
  static MonthlyListItem itemToDomain(MonthlyListItemDto dto) => MonthlyListItem(
        itemId: dto.itemId,
        quantity: dto.quantity,
        variantId: dto.variantId,
        name: dto.name,
      );

  static MonthlyList toDomain(MonthlyListDto dto) => MonthlyList(
        id: dto.id,
        name: dto.name,
        restaurantId: dto.restaurantId,
        restaurantName: dto.restaurantName,
        items: dto.items.map(itemToDomain).toList(),
        isActive: dto.isActive,
        lastOrderedAt: dto.lastOrderedAt,
        lastOrderId: dto.lastOrderId,
        createdAt: dto.createdAt,
      );

  /// Newest first, matching the backend's own `createdAt` sort — kept here so
  /// a list rebuilt locally after an edit keeps the same order as a refetch.
  static List<MonthlyList> toDomainList(List<MonthlyListDto> dtos) =>
      dtos.map(toDomain).toList();

  /// Item shape accepted by both create and update. `variantId` is omitted
  /// rather than sent empty — the validator treats it as optional.
  static Map<String, dynamic> itemToJson(MonthlyListItem item) => {
        'itemId': item.itemId,
        'quantity': item.quantity,
        if (item.variantId.trim().isNotEmpty) 'variantId': item.variantId,
      };
}
