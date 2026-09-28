import 'json_reader.dart';

/// The `FoodUser` document, as returned by verify-otp, `/me` and `/profile`.
class UserDto {
  const UserDto({
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

  factory UserDto.fromJson(Map<String, dynamic> json) => UserDto(
        id: json.id(),
        phone: json.str('phone'),
        name: json.str('name'),
        email: json.str('email'),
        profileImage: json.imageUrl('profileImage'),
        countryCode: json.str('countryCode', '+91'),
        referralCode: json.str('referralCode'),
        gender: json.str('gender'),
        dateOfBirth: json.dateOrNull('dateOfBirth'),
        isVerified: json.boolean('isVerified'),
      );

  /// Cached locally so the app can render a signed-in shell before `/me`
  /// resolves.
  Map<String, dynamic> toJson() => {
        '_id': id,
        'phone': phone,
        'name': name,
        'email': email,
        'profileImage': profileImage,
        'countryCode': countryCode,
        'referralCode': referralCode,
        'gender': gender,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'isVerified': isVerified,
      };
}

class WalletDto {
  const WalletDto({
    this.balance = 0,
    this.referralEarnings = 0,
    this.transactions = const [],
  });

  final double balance;
  final double referralEarnings;
  final List<WalletTransactionDto> transactions;

  factory WalletDto.fromJson(Map<String, dynamic> json) => WalletDto(
        balance: json.dbl('balance'),
        referralEarnings: json.dbl('referralEarnings'),
        transactions: json
            .objects('transactions')
            .map(WalletTransactionDto.fromJson)
            .toList(),
      );
}

class WalletTransactionDto {
  const WalletTransactionDto({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.description = '',
    this.status = 'Completed',
  });

  final String id;
  final String type;
  final double amount;
  final DateTime date;
  final String description;
  final String status;

  factory WalletTransactionDto.fromJson(Map<String, dynamic> json) =>
      WalletTransactionDto(
        id: json.id(),
        type: json.str('type', 'addition'),
        amount: json.dbl('amount'),
        date: json.dateOrNull('date') ?? json.date('createdAt'),
        description: json.str('description'),
        status: json.str('status', 'Completed'),
      );
}
