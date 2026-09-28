/// Pure input validation used by forms. Returns null when valid.
abstract final class Validators {
  static final _phone = RegExp(r'^[6-9]\d{9}$');
  static final _email = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  static String? phone(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Enter your mobile number';
    if (!_phone.hasMatch(v)) return 'Enter a valid 10-digit mobile number';
    return null;
  }

  static String? otp(String? value, {int length = 4}) {
    final v = (value ?? '').trim();
    if (v.length != length) return 'Enter the $length-digit code';
    if (int.tryParse(v) == null) return 'The code must be numeric';
    return null;
  }

  static String? required(String? value, String field) {
    if ((value ?? '').trim().isEmpty) return '$field is required';
    return null;
  }

  static String? email(String? value, {bool optional = true}) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return optional ? null : 'Email is required';
    if (!_email.hasMatch(v)) return 'Enter a valid email';
    return null;
  }

  static String? pincode(String? value, {bool optional = true}) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return optional ? null : 'Pincode is required';
    if (v.length != 6 || int.tryParse(v) == null) return 'Enter a valid 6-digit pincode';
    return null;
  }
}
