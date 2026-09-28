/// An optional extra attached to a cart line (cutlery, a dip, a bigger bag).
class Addon {
  const Addon({
    required this.id,
    required this.name,
    required this.price,
    this.description = '',
    this.isVeg = true,
    this.imageUrl = '',
    this.groupName = '',
  });

  final String id;
  final String name;
  final double price;
  final String description;
  final bool isVeg;
  final String imageUrl;
  final String groupName;

  @override
  bool operator ==(Object other) => other is Addon && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Add-ons arrive grouped, with min/max selection rules the sheet enforces.
class AddonGroup {
  const AddonGroup({
    required this.name,
    required this.options,
    this.minSelect = 0,
    this.maxSelect = 0,
    this.selectionLabel = '',
  });

  final String name;
  final List<Addon> options;
  final int minSelect;
  final int maxSelect;
  final String selectionLabel;

  bool get isRequired => minSelect > 0;
  bool get isSingleSelect => maxSelect == 1;
  bool get hasLimit => maxSelect > 0;
}
