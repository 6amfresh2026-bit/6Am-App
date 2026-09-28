/// The signed-in customer.
class User {
  const User({
    required this.id,
    required this.phone,
    this.name = '',
    this.email = '',
    this.profileImage = '',
    this.countryCode = '+91',
    this.referralCode = '',
    this.gender = '',
    this.dateOfBirth,
    this.isVerified = false,
  });

  final String id;
  final String phone;
  final String name;
  final String email;
  final String profileImage;
  final String countryCode;
  final String referralCode;
  final String gender;
  final DateTime? dateOfBirth;
  final bool isVerified;

  String get displayName => name.trim().isEmpty ? 'Suvio customer' : name.trim();

  /// Sign-in is by phone alone, so an account exists before we know who owns
  /// it. Until a name is on the record the sign-up is only half done, and the
  /// app asks for the remaining details before letting them shop.
  ///
  /// Keyed on the name only — the same test the backend uses for its
  /// `isNewUser` flag — so the two never disagree about who still owes us
  /// details. Older accounts that were created without an email are not
  /// dragged back through sign-up for it.
  bool get needsRegistrationDetails => name.trim().isEmpty;

  String get maskedPhone =>
      phone.length >= 10 ? '$countryCode ${phone.substring(0, 5)} ${phone.substring(5)}' : phone;

  User copyWith({
    String? name,
    String? email,
    String? profileImage,
    String? gender,
    DateTime? dateOfBirth,
  }) =>
      User(
        id: id,
        phone: phone,
        name: name ?? this.name,
        email: email ?? this.email,
        profileImage: profileImage ?? this.profileImage,
        countryCode: countryCode,
        referralCode: referralCode,
        gender: gender ?? this.gender,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        isVerified: isVerified,
      );
}

/// Wallet balance plus its ledger, as returned by the user wallet endpoint.
class Wallet {
  const Wallet({
    this.balance = 0,
    this.referralEarnings = 0,
    this.transactions = const [],
  });

  final double balance;
  final double referralEarnings;
  final List<WalletTransaction> transactions;
}

/// Gateway parameters the backend mints for a wallet top-up. The app never
/// decides the amount charged — the backend created the Razorpay order for
/// exactly [amountPaise] and re-verifies the signature before crediting.
class WalletTopupOrder {
  const WalletTopupOrder({
    required this.key,
    required this.orderId,
    required this.amountPaise,
    this.currency = 'INR',
  });

  final String key;
  final String orderId;
  final int amountPaise;
  final String currency;
}

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.description = '',
    this.status = 'Completed',
  });

  final String id;

  /// `addition` | `deduction` | `refund`
  final String type;
  final double amount;
  final DateTime date;
  final String description;
  final String status;

  bool get isCredit => type != 'deduction';
}
