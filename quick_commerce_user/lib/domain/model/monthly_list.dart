/// A saved, reusable basket from one restaurant that the customer re-orders
/// whenever they choose.
///
/// Deliberately *not* a subscription: nothing here fires on a schedule. The
/// list only remembers what to order — never a price — so every order placed
/// from it is re-priced and re-validated fresh by the backend.
class MonthlyListItem {
  const MonthlyListItem({
    required this.itemId,
    required this.quantity,
    this.variantId = '',
    this.name = '',
  });

  final String itemId;
  final int quantity;
  final String variantId;

  /// Snapshot of the product name taken when the list was saved, so a renamed
  /// or withdrawn product still shows something meaningful in the list.
  final String name;

  MonthlyListItem copyWith({int? quantity}) => MonthlyListItem(
        itemId: itemId,
        quantity: quantity ?? this.quantity,
        variantId: variantId,
        name: name,
      );

  /// Identity within a list: the same product in two variants is two lines.
  String get lineId => variantId.isEmpty ? itemId : '$itemId::$variantId';

  @override
  bool operator ==(Object other) =>
      other is MonthlyListItem && other.lineId == lineId;

  @override
  int get hashCode => lineId.hashCode;
}

class MonthlyList {
  const MonthlyList({
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
  final List<MonthlyListItem> items;
  final bool isActive;
  final DateTime? lastOrderedAt;
  final String lastOrderId;
  final DateTime? createdAt;

  int get itemCount => items.length;

  int get totalQuantity => items.fold(0, (sum, i) => sum + i.quantity);

  bool get isEmpty => items.isEmpty;

  /// An inactive or empty list cannot be ordered — the backend rejects both,
  /// so the button that would call it is disabled rather than failing later.
  bool get canOrder => isActive && items.isNotEmpty;

  bool get hasBeenOrdered => lastOrderedAt != null;

  MonthlyList copyWith({
    String? name,
    List<MonthlyListItem>? items,
    bool? isActive,
    DateTime? lastOrderedAt,
    String? lastOrderId,
  }) =>
      MonthlyList(
        id: id,
        name: name ?? this.name,
        restaurantId: restaurantId,
        restaurantName: restaurantName,
        items: items ?? this.items,
        isActive: isActive ?? this.isActive,
        lastOrderedAt: lastOrderedAt ?? this.lastOrderedAt,
        lastOrderId: lastOrderId ?? this.lastOrderId,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) => other is MonthlyList && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
