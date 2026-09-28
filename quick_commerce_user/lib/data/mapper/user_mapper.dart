import '../../domain/model/user.dart';
import '../dto/user_dto.dart';

abstract final class UserMapper {
  static User toDomain(UserDto dto) => User(
        id: dto.id,
        phone: dto.phone,
        name: dto.name,
        email: dto.email,
        profileImage: dto.profileImage,
        countryCode: dto.countryCode,
        referralCode: dto.referralCode,
        gender: dto.gender,
        dateOfBirth: dto.dateOfBirth,
        isVerified: dto.isVerified,
      );

  static Wallet walletToDomain(WalletDto dto) => Wallet(
        balance: dto.balance,
        referralEarnings: dto.referralEarnings,
        transactions: dto.transactions
            .map((t) => WalletTransaction(
                  id: t.id,
                  type: t.type,
                  amount: t.amount,
                  date: t.date,
                  description: t.description,
                  status: t.status,
                ))
            .toList(),
      );
}
