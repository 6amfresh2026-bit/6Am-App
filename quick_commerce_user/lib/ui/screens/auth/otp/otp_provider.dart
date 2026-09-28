import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../di/app_providers.dart';
import '../../../../di/repository_providers.dart';
import '../../../../domain/repository/auth_repository.dart';
import 'otp_state.dart';

/// Keyed by phone number so re-entering the flow does not inherit a stale timer.
class OtpController extends FamilyNotifier<OtpState, String> {
  static const _resendSeconds = 30;

  Timer? _timer;

  @override
  OtpState build(String phone) {
    ref.onDispose(() => _timer?.cancel());
    // Only arm the timer here. Touching `state` before build() returns would
    // read a provider that Riverpod has not finished initialising.
    _tick();
    return const OtpState(secondsRemaining: _resendSeconds);
  }

  /// Counts the resend window down. The callback runs after build(), so it can
  /// read `state` safely.
  void _tick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = state.secondsRemaining - 1;
      state = state.copyWith(secondsRemaining: next);
      if (next <= 0) timer.cancel();
    });
  }

  void _restartCountdown() {
    state = state.copyWith(secondsRemaining: _resendSeconds);
    _tick();
  }

  void setCode(String code) =>
      state = state.copyWith(code: code, clearFailure: true);

  Future<AuthSession?> verify() async {
    if (!state.canVerify) return null;

    state = state.copyWith(isVerifying: true, clearFailure: true);
    try {
      final session = await ref
          .read(authRepositoryProvider)
          .verifyOtp(phone: arg, otp: state.code);

      ref.read(authProvider.notifier).setUser(session.user);
      state = state.copyWith(isVerifying: false);
      return session;
    } catch (e) {
      state = state.copyWith(
        isVerifying: false,
        failure: ErrorMapper.toFailure(e),
      );
      return null;
    }
  }

  Future<void> resend() async {
    if (!state.canResend) return;

    state = state.copyWith(isResending: true, clearFailure: true);
    try {
      final result = await ref.read(authRepositoryProvider).requestOtp(arg);
      state = state.copyWith(isResending: false, debugOtp: result.debugOtp);
      _restartCountdown();
    } catch (e) {
      state = state.copyWith(
        isResending: false,
        failure: ErrorMapper.toFailure(e),
      );
    }
  }
}

final otpProvider = NotifierProvider.family<OtpController, OtpState, String>(
  OtpController.new,
);
