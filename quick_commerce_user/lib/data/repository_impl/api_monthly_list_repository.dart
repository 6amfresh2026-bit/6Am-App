import '../../core/errors/app_exception.dart';
import '../../core/network/api_client.dart';
import '../../domain/model/address.dart';
import '../../domain/model/monthly_list.dart';
import '../../domain/model/order.dart';
import '../../domain/model/payment_method.dart';
import '../../domain/repository/monthly_list_repository.dart';
import '../dto/json_reader.dart';
import '../dto/monthly_list_dto.dart';
import '../mapper/address_mapper.dart';
import '../mapper/monthly_list_mapper.dart';
import '../mapper/order_mapper.dart';
import 'api_paths.dart';

class ApiMonthlyListRepository implements MonthlyListRepository {
  ApiMonthlyListRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<MonthlyList>> list() async {
    final json = await _client.get(ApiPaths.monthlyLists, requiresAuth: true);
    if (json is! Map<String, dynamic>) return const [];
    return MonthlyListMapper.toDomainList(
      json.objects('lists').map(MonthlyListDto.fromJson).toList(),
    );
  }

  @override
  Future<MonthlyList> getById(String listId) async {
    final json = await _client.get(
      ApiPaths.monthlyList(listId),
      requiresAuth: true,
    );
    return _single(json);
  }

  @override
  Future<MonthlyList> create({
    required String restaurantId,
    required List<MonthlyListItem> items,
    String? name,
  }) async {
    final json = await _client.post(
      ApiPaths.monthlyLists,
      body: {
        'restaurantId': restaurantId,
        'items': items.map(MonthlyListMapper.itemToJson).toList(),
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      },
      requiresAuth: true,
    );
    return _single(json);
  }

  @override
  Future<MonthlyList> update(
    String listId, {
    String? name,
    bool? isActive,
    List<MonthlyListItem>? items,
  }) async {
    final json = await _client.patch(
      ApiPaths.monthlyList(listId),
      body: {
        'name': ?name?.trim(),
        'isActive': ?isActive,
        if (items != null)
          'items': items.map(MonthlyListMapper.itemToJson).toList(),
      },
      requiresAuth: true,
    );
    return _single(json);
  }

  @override
  Future<void> delete(String listId) =>
      _client.delete(ApiPaths.monthlyList(listId), requiresAuth: true);

  @override
  Future<PlacedOrder> placeOrder(
    String listId, {
    String? addressId,
    Address? address,
    PaymentMethod method = PaymentMethod.cash,
    String deliveryMode = 'basic',
    String? couponCode,
  }) async {
    // A saved address is passed by id so the backend resolves the stored copy;
    // an unsaved one is sent inline in the same shape order creation accepts.
    final json = await _client.post(
      ApiPaths.monthlyListOrder(listId),
      body: {
        if (addressId != null && addressId.isNotEmpty) 'addressId': addressId,
        if (address != null) 'address': AddressMapper.toOrderJson(address),
        'paymentMethod': method.orderWireValue,
        'deliveryMode': deliveryMode,
        if (couponCode != null && couponCode.trim().isNotEmpty)
          'couponCode': couponCode.trim(),
      },
      requiresAuth: true,
    );

    if (json is! Map<String, dynamic>) {
      throw const ParseException('Unexpected order response.');
    }
    return OrderMapper.placedFromJson(json);
  }

  MonthlyList _single(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const ParseException('Unexpected monthly list response.');
    }
    return MonthlyListMapper.toDomain(
      MonthlyListDto.fromJson(json.mapAt('list')),
    );
  }
}
