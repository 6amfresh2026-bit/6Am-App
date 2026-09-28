import '../../domain/model/addon.dart';
import '../dto/addon_dto.dart';

abstract final class AddonMapper {
  static Addon toDomain(AddonDto dto) => Addon(
        id: dto.id,
        name: dto.name,
        price: dto.price,
        description: dto.description,
        isVeg: dto.isVeg,
        imageUrl: dto.image,
        groupName: dto.groupName,
      );

  static AddonGroup groupToDomain(AddonGroupDto dto) => AddonGroup(
        name: dto.name,
        options: dto.options.map(toDomain).toList(),
        minSelect: dto.minSelect,
        maxSelect: dto.maxSelect,
        selectionLabel: dto.selectionLabel,
      );

  static List<AddonGroup> groupsToDomain(List<AddonGroupDto> dtos) =>
      dtos.where((g) => g.options.isNotEmpty).map(groupToDomain).toList();
}
