import '../../../../core/errors/failure.dart';

class LoginState {
  const LoginState({
    this.phone = '',
    this.isSubmitting = false,
    this.validationError,
    this.failure,
    this.debugOtp,
    this.otpSent = false,
  });

  final String phone;
  final bool isSubmitting;
  final String? validationError;
  final Failure? failure;

  /// Echoed by the backend outside production; passed to the OTP screen as a hint.
  final String? debugOtp;
  final bool otpSent;

  bool get canSubmit => phone.length == 10 && !isSubmitting;

  LoginState copyWith({
    String? phone,
    bool? isSubmitting,
    String? validationError,
    Failure? failure,
    String? debugOtp,
    bool? otpSent,
    bool clearErrors = false,
  }) =>
      LoginState(
        phone: phone ?? this.phone,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        validationError: clearErrors ? null : (validationError ?? this.validationError),
        failure: clearErrors ? null : (failure ?? this.failure),
        debugOtp: debugOtp ?? this.debugOtp,
        otpSent: otpSent ?? this.otpSent,
      );
}
