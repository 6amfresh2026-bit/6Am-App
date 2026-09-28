import '../../core/network/api_client.dart';
import '../../domain/model/category.dart';
import '../../domain/model/sub_category.dart';
import '../../domain/repository/category_repository.dart';
import '../../domain/repository/product_repository.dart';
import '../../domain/service/catalog_grouping_service.dart';
import '../dto/category_dto.dart';
import '../dto/json_reader.dart';
import '../mapper/category_mapper.dart';
import 'api_paths.dart';

class ApiCategoryRepository implements CategoryRepository {
  ApiCategoryRepository(
    this._client, {
    required ProductRepository productRepository,
    CatalogGroupingService? grouping,
  })  : _products = productRepository,
        _grouping = grouping ?? const CatalogGroupingService();

  final ApiClient _client;
  final ProductRepository _products;
  final CatalogGroupingService _grouping;

  @override
  Future<List<Category>> topLevel() async {
    final json = await _client.get(ApiPaths.adminCategories);
    final categories = json is Map<String, dynamic>
        ? CategoryMapper.toDomainList(
            json.objects('categories').map(CategoryDto.fromJson).toList(),
          )
        : const <Category>[];

    if (categories.isNotEmpty) return categories;

    // That endpoint only returns *global* categories — ones with no
    // `restaurantId`. A deployment whose categories were all created by
    // sellers gets an empty list, which left the Categories tab blank even
    // though every product carries a category. Deriving them from the
    // catalogue is the same trick sub-categories and sellers already use.
    final page = await _products.list(pageSize: 100);
    return _grouping.categoriesFrom(page.items);
  }

  @override
  Future<List<SubCategory>> subCategoriesOf(String categoryId) async {
    // No sub-category resource exists upstream, so they are derived from the
    // brands present in the category's items.
    final page = await _products.list(categoryId: categoryId, pageSize: 50);
    return _grouping.subCategoriesFrom(page.items, categoryId);
  }
}
