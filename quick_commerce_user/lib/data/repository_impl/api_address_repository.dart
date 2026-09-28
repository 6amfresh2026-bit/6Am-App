import '../../core/errors/app_exception.dart';
import '../../core/network/api_client.dart';
import '../../domain/model/address.dart';
import '../../domain/repository/address_repository.dart';
import '../dto/address_dto.dart';
import '../dto/json_reader.dart';
import '../mapper/address_mapper.dart';
import 'api_paths.dart';

class ApiAddressRepository implements AddressRepository {
  ApiAddressRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<Address>> list() async {
    final json = await _client.get(ApiPaths.addresses, requiresAuth: true);
    if (json is! Map<String, dynamic>) return const [];
    return AddressMapper.toDomainList(
      json.objects('addresses').map(AddressDto.fromJson).toList(),
    );
  }

  @override
  Future<Address> add(Address address) async {
    final json = await _client.post(
      ApiPaths.addresses,
      body: AddressMapper.toCreateJson(address),
      requiresAuth: true,
    );
    return _single(json);
  }

  @override
  Future<Address> update(Address address) async {
    final json = await _client.patch(
      ApiPaths.address(address.id),
      body: AddressMapper.toCreateJson(address),
      requiresAuth: true,
    );
    return _single(json);
  }

  @override
  Future<void> delete(String addressId) =>
      _client.delete(ApiPaths.address(addressId), requiresAuth: true);

  @override
  Future<Address> setDefault(String addressId) async {
    final json = await _client.patch(
      ApiPaths.addressDefault(addressId),
      requiresAuth: true,
    );
    return _single(json);
  }

  Address _single(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const ParseException('Unexpected address response.');
    }
    return AddressMapper.toDomain(AddressDto.fromJson(json.mapAt('address')));
  }
}
