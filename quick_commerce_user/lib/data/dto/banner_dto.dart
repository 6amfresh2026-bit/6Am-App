import 'json_reader.dart';

/// Landing banners. Hero/under-250/home-promotion use `imageUrl` + `sortOrder`;
/// top banners use `image` + `order`, so both spellings are read.
class BannerDto {
  const BannerDto({
    required this.id,
    required this.imageUrl,
    this.videoUrl = '',
    this.title = '',
    this.ctaText = '',
    this.ctaLink = '',
    this.sortOrder = 0,
  });

  final String id;
  final String imageUrl;
  final String videoUrl;
  final String title;
  final String ctaText;
  final String ctaLink;
  final int sortOrder;

  factory BannerDto.fromJson(Map<String, dynamic> json) => BannerDto(
        id: json.id(),
        imageUrl: json.imageUrl('imageUrl').isNotEmpty
            ? json.imageUrl('imageUrl')
            : json.imageUrl('image'),
        videoUrl: json.firstStr(['videoUrl', 'video', 'mediaUrl', 'video_url']),
        title: json.firstStr(['title', 'label']),
        ctaText: json.str('ctaText'),
        ctaLink: json.firstStr(['ctaLink', 'link']),
        sortOrder: json.containsKey('sortOrder')
            ? json.integer('sortOrder')
            : json.integer('order'),
      );
}
