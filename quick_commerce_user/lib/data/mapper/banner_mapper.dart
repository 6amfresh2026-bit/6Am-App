import '../../domain/model/banner.dart';
import '../dto/banner_dto.dart';

abstract final class BannerMapper {
  static PromoBanner toDomain(BannerDto dto) => PromoBanner(
        id: dto.id,
        imageUrl: dto.imageUrl,
        videoUrl: dto.videoUrl,
        title: dto.title,
        ctaText: dto.ctaText,
        ctaLink: dto.ctaLink,
        sortOrder: dto.sortOrder,
      );

  static List<PromoBanner> toDomainList(List<BannerDto> dtos) => dtos
      .where((d) => d.imageUrl.trim().isNotEmpty || d.videoUrl.trim().isNotEmpty)
      .map(toDomain)
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
}
