import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../di/app_providers.dart';
import '../../../../di/repository_providers.dart';
import 'register_state.dart';

/// Finishes sign-up: the phone is already verified, this collects who it
/// belongs to.
///
/// The details go to `PATCH /food/user/profile` rather than riding along with
/// the OTP, because whether an account is new is only known *after* the code
/// is checked — and by then that OTP is spent and cannot carry anything else.
class RegisterController extends Notifier<RegisterState> {
  @override
  RegisterState build() {
    // A repeat of this step — app closed mid-sign-up, or an email added to an
    // older account — starts from whatever is already on the record.
    final user = ref.read(authProvider).user;
    return RegisterState(name: user?.name ?? '', email: user?.email ?? '');
  }

  void setName(String value) =>
      state = state.copyWith(name: value, clearFailure: true);

  void setEmail(String value) =>
      state = state.copyWith(email: value, clearFailure: true);

  /// Returns true once the profile is saved and the session holds the new
  /// details, so the caller can move on.
  Future<bool> submit() async {
    if (state.isSubmitting) return false;

    if (!state.isValid) {
      state = state.copyWith(showErrors: true);
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearFailure: true);
    try {
      final user = await ref.read(authRepositoryProvider).updateProfile(
            name: state.name.trim(),
            email: state.email.trim(),
          );
      ref.read(authProvider.notifier).setUser(user);
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      // The server does its own email checks — consecutive dots, doubled
      // domains — so show what it actually objected to rather than a generic
      // failure the customer cannot act on.
      state = state.copyWith(
        isSubmitting: false,
        showErrors: true,
        failure: ErrorMapper.toFailure(e),
      );
      return false;
    }
  }
}

final registerProvider =
    NotifierProvider<RegisterController, RegisterState>(RegisterController.new);
