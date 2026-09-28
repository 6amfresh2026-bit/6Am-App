import '../../../../core/errors/failure.dart';

class OtpState {
  const OtpState({
    this.code = '',
    this.isVerifying = false,
    this.isResending = false,
    this.secondsRemaining = 30,
    this.failure,
    this.debugOtp,
  });

  final String code;
  final bool isVerifying;
  final bool isResending;
  final int secondsRemaining;
  final Failure? failure;
  final String? debugOtp;

  bool get canResend => secondsRemaining <= 0 && !isResending;
  bool get canVerify => code.length == 4 && !isVerifying;
  bool get hasError => failure != null;

  OtpState copyWith({
    String? code,
    bool? isVerifying,
    bool? isResending,
    int? secondsRemaining,
    Failure? failure,
    String? debugOtp,
    bool clearFailure = false,
  }) =>
      OtpState(
        code: code ?? this.code,
        isVerifying: isVerifying ?? this.isVerifying,
        isResending: isResending ?? this.isResending,
        secondsRemaining: secondsRemaining ?? this.secondsRemaining,
        failure: clearFailure ? null : (failure ?? this.failure),
        debugOtp: debugOtp ?? this.debugOtp,
      );
}
