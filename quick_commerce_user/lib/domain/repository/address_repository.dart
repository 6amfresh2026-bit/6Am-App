import '../model/address.dart';

abstract interface class AddressRepository {
  Future<List<Address>> list();

  Future<Address> add(Address address);

  Future<Address> update(Address address);

  Future<void> delete(String addressId);

  Future<Address> setDefault(String addressId);
}
