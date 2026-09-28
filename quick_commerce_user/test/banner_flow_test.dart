import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_user/core/network/media_url.dart';
import 'package:quick_commerce_user/data/dto/banner_dto.dart';
import 'package:quick_commerce_user/data/dto/json_reader.dart';
import 'package:quick_commerce_user/data/mapper/banner_mapper.dart';

void main() {
  setUpAll(() => MediaUrl.configure('https://quick.appzeto.com/api/v1'));

  test('root-relative uploads become absolute against the API host', () {
    expect(
      MediaUrl.resolve('/uploads/food/a.webp'),
      'https://quick.appzeto.com/uploads/food/a.webp',
    );
    expect(
      MediaUrl.resolve('https://cdn.example.com/a.webp'),
      'https://cdn.example.com/a.webp',
    );
    expect(MediaUrl.resolve(''), '');
  });

  test('the live home-promotion payload parses into usable banners', () {
    // Verbatim shape of GET /api/v1/food/hero-banners/home-promotion/public.
    final body = <String, dynamic>{
      'banners': [
        {
          '_id': '6a70c0228947c8e2902a0e3f',
          'imageUrl': '/uploads/food/home-promotion-banners/1785774114315.webp',
          'title': '',
          'ctaLink': '',
          'sortOrder': 2,
          'isActive': true,
        },
        {
          '_id': '6a70c0158947c8e2902a0e3c',
          'imageUrl': '/uploads/food/home-promotion-banners/1785774101172.webp',
          'sortOrder': 1,
          'isActive': true,
        },
        // No image — must never reach the carousel.
        {'_id': 'broken', 'imageUrl': '', 'sortOrder': 0},
      ],
    };

    final banners = BannerMapper.toDomainList(
      body.objects('banners').map(BannerDto.fromJson).toList(),
    );

    expect(banners.length, 2);
    expect(banners.first.id, '6a70c0158947c8e2902a0e3c'); // sortOrder honoured
    expect(
      banners.first.imageUrl,
      'https://quick.appzeto.com/uploads/food/home-promotion-banners/1785774101172.webp',
    );
  });
}
