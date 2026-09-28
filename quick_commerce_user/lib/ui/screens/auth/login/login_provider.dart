import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/validators.dart';
import '../../../../di/repository_providers.dart';
import 'login_state.dart';

class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  void setPhone(String value) {
    state = state.copyWith(phone: value.trim(), clearErrors: true);
  }

  /// Requests an OTP. Returns true when the backend accepted the number.
  Future<bool> requestOtp() async {
    final error = Validators.phone(state.phone);
    if (error != null) {
      state = state.copyWith(validationError: error);
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearErrors: true);
    try {
      final result =
          await ref.read(authRepositoryProvider).requestOtp(state.phone);
      state = state.copyWith(
        isSubmitting: false,
        otpSent: true,
        debugOtp: result.debugOtp,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        failure: ErrorMapper.toFailure(e),
      );
      return false;
    }
  }
}

final loginProvider =
    NotifierProvider<LoginController, LoginState>(LoginController.new);
