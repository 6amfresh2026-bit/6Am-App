import '../../core/utils/validators.dart';
import '../model/address.dart';

/// Field-level validation for the address form. Pure Dart, no Flutter.
class AddressValidator {
  const AddressValidator();

  Map<String, String> validate(Address address) {
    final errors = <String, String>{};

    final street = Validators.required(address.street, 'Street / area');
    if (street != null) errors['street'] = street;

    final city = Validators.required(address.city, 'City');
    if (city != null) errors['city'] = city;

    final state = Validators.required(address.state, 'State');
    if (state != null) errors['state'] = state;

    final pin = Validators.pincode(address.zipCode);
    if (pin != null) errors['zipCode'] = pin;

    if (address.phone.trim().isNotEmpty) {
      final phone = Validators.phone(address.phone);
      if (phone != null) errors['phone'] = phone;
    }

    // The backend requires latitude/longitude on create — an unpinned address
    // would be rejected server-side, so catch it in the form.
    if (!address.hasCoordinates) {
      errors['location'] = 'Pin the location on the map';
    }

    return errors;
  }

  bool isValid(Address address) => validate(address).isEmpty;
}
