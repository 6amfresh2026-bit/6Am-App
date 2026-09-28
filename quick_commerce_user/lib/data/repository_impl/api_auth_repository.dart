import 'dart:convert';

import '../../core/errors/app_exception.dart';
import '../../core/local_storage/local_storage.dart';
import '../../core/network/api_client.dart';
import '../../core/network/dio_api_client.dart';
import '../../domain/model/user.dart';
import '../../domain/repository/auth_repository.dart';
import '../../platform/notification/notification_service.dart';
import '../dto/json_reader.dart';
import '../dto/user_dto.dart';
import '../mapper/user_mapper.dart';
import 'api_paths.dart';

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(
    this._client,
    this._storage,
    this._tokenStore,
    this._push,
  ) {
    // Installed here rather than in the client so the transport layer keeps no
    // knowledge of the auth endpoints.
    _tokenStore.onRefresh = _refresh;
  }

  final ApiClient _client;
  final LocalStorage _storage;
  final LocalAuthTokenStore _tokenStore;
  final NotificationService _push;

  @override
  bool get isSignedIn =>
      (_storage.getString(StorageKeys.accessToken) ?? '').isNotEmpty;

  @override
  User? get cachedUser {
    final raw = _storage.getString(StorageKeys.userJson);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return UserMapper.toDomain(UserDto.fromJson(json));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<OtpRequestResult> requestOtp(String phone) async {
    final json = await _client.post(
      ApiPaths.requestOtp,
      body: {'phone': phone.trim()},
    );
    final map = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    final otp = map.str('otp');
    return OtpRequestResult(
      phone: map.str('phone', phone),
      // Present only outside production — shown as a hint on the OTP screen.
      debugOtp: otp.isEmpty ? null : otp,
    );
  }

  @override
  Future<AuthSession> verifyOtp({
    required String phone,
    required String otp,
    String? name,
  }) async {
    final json = await _client.post(
      ApiPaths.verifyOtp,
      body: {
        'phone': phone.trim(),
        'otp': otp.trim(),
        'platform': 'mobile',
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      },
    );

    if (json is! Map<String, dynamic>) {
      throw const ParseException('Unexpected sign-in response.');
    }

    await _persistTokens(
      access: json.str('accessToken'),
      refresh: json.str('refreshToken'),
    );

    final user = UserMapper.toDomain(UserDto.fromJson(json.mapAt('user')));
    await _cacheUser(user);

    // Must follow token persistence — the save call is authenticated. Push is
    // not worth failing a sign-in over, so it never throws.
    await _push.registerDevice();

    return AuthSession(user: user, isNewUser: json.boolean('isNewUser'));
  }

  @override
  Future<User> currentUser() async {
    final json = await _client.get(ApiPaths.me, requiresAuth: true);
    if (json is! Map<String, dynamic>) {
      throw const ParseException('Unexpected profile response.');
    }
    final user = UserMapper.toDomain(UserDto.fromJson(json.mapAt('user')));
    await _cacheUser(user);
    return user;
  }

  @override
  Future<User> updateProfile({
    String? name,
    String? email,
    String? gender,
    DateTime? dateOfBirth,
  }) async {
    final json = await _client.patch(
      ApiPaths.profile,
      body: {
        if (name != null) 'name': name.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (gender != null && gender.isNotEmpty) 'gender': gender,
        if (dateOfBirth != null)
          'dateOfBirth': dateOfBirth.toIso8601String().split('T').first,
      },
      requiresAuth: true,
    );

    if (json is! Map<String, dynamic>) {
      throw const ParseException('Unexpected profile response.');
    }
    final user = UserMapper.toDomain(UserDto.fromJson(json.mapAt('user')));
    await _cacheUser(user);
    return user;
  }

  @override
  Future<Wallet> wallet() async {
    final json = await _client.get(ApiPaths.wallet, requiresAuth: true);
    if (json is! Map<String, dynamic>) return const Wallet();
    return UserMapper.walletToDomain(WalletDto.fromJson(json.mapAt('wallet')));
  }

  @override
  Future<WalletTopupOrder> createWalletTopupOrder(double amountRupees) async {
    // Backend takes rupees and mints a Razorpay order for the paise equivalent.
    final json = await _client.post(
      ApiPaths.walletTopupOrder,
      body: {'amount': amountRupees},
      requiresAuth: true,
    );
    if (json is! Map<String, dynamic>) {
      throw const ParseException('Unexpected top-up response.');
    }
    final rz = json.mapAt('razorpay');
    return WalletTopupOrder(
      key: rz.str('key'),
      orderId: rz.str('orderId'),
      amountPaise: rz.integer('amount'),
      currency: rz.str('currency', 'INR'),
    );
  }

  @override
  Future<Wallet> verifyWalletTopup({
    required String orderId,
    required String paymentId,
    required String signature,
    required double amountRupees,
  }) async {
    final json = await _client.post(
      ApiPaths.walletTopupVerify,
      body: {
        'razorpayOrderId': orderId,
        'razorpayPaymentId': paymentId,
        'razorpaySignature': signature,
        // Rupees — the backend credits this exact figure after re-checking the
        // signature server-side.
        'amount': amountRupees,
      },
      requiresAuth: true,
    );
    if (json is! Map<String, dynamic>) return const Wallet();
    return UserMapper.walletToDomain(WalletDto.fromJson(json.mapAt('wallet')));
  }

  @override
  Future<void> signOut() async {
    // Before the tokens go: removing the device server-side needs the session.
    await _push.unregisterDevice();

    final refresh = _storage.getString(StorageKeys.refreshToken);
    if (refresh != null && refresh.isNotEmpty) {
      // The backend invalidates the refresh token; a failure here still lets
      // the user out locally.
      try {
        await _client.post(ApiPaths.logout, body: {'refreshToken': refresh});
      } on AppException {
        // Ignored on purpose — local sign-out must always succeed.
      }
    }
    await _tokenStore.clearSession();
  }

  @override
  Future<void> deleteAccount() async {
    await _push.unregisterDevice();
    await _client.delete(ApiPaths.profile, requiresAuth: true);
    await _tokenStore.clearSession();
  }

  Future<bool> _refresh() async {
    final refresh = _storage.getString(StorageKeys.refreshToken);
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final json = await _client.post(
        ApiPaths.refreshToken,
        body: {'refreshToken': refresh},
      );
      if (json is! Map<String, dynamic>) return false;
      final access = json.str('accessToken');
      if (access.isEmpty) return false;
      await _persistTokens(
        access: access,
        refresh: json.str('refreshToken', refresh),
      );
      return true;
    } on AppException {
      return false;
    }
  }

  Future<void> _persistTokens({required String access, required String refresh}) async {
    if (access.isNotEmpty) {
      await _storage.setString(StorageKeys.accessToken, access);
    }
    if (refresh.isNotEmpty) {
      await _storage.setString(StorageKeys.refreshToken, refresh);
    }
  }

  Future<void> _cacheUser(User user) => _storage.setString(
        StorageKeys.userJson,
        jsonEncode(
          UserDto(
            id: user.id,
            phone: user.phone,
            name: user.name,
            email: user.email,
            profileImage: user.profileImage,
            countryCode: user.countryCode,
            referralCode: user.referralCode,
            gender: user.gender,
            dateOfBirth: user.dateOfBirth,
            isVerified: user.isVerified,
          ).toJson(),
        ),
      );
}
