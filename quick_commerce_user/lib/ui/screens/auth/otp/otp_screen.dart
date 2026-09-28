import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../di/app_providers.dart';
import '../../../../navigation/route_paths.dart';
import '../../../common/widgets/buttons/primary_button.dart';
import '../../../common/widgets/inputs/otp_input.dart';
import 'otp_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone, this.debugOtp});

  final String phone;

  /// Non-production backends echo the OTP; showing it beats guessing in dev.
  final String? debugOtp;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  /// The code the login call already handed us, replaced by a fresher one once
  /// the user hits resend. Read directly rather than pushed into the provider,
  /// which kept a whole initialisation path alive for a dev-only hint.
  String? _debugOtp(String? fromState) => fromState ?? widget.debugOtp;

  Future<void> _verify() async {
    final session = await ref.read(otpProvider(widget.phone).notifier).verify();
    if (session == null || !mounted) return;

    // Signing in creates the account off the phone number alone, so a first
    // visit arrives here with nothing on the record but a number. Collect the
    // name and email before Home. `isNewUser` is the server's own read of
    // that; the local check covers a sign-up abandoned on the next screen.
    if (session.isNewUser || session.user.needsRegistrationDetails) {
      context.go(RoutePaths.register);
      return;
    }

    // Always land on Home. When there is no address yet, Home raises the
    // location prompt over itself — collecting it after sign-in, since saving
    // an address is an authenticated call.
    await ref.read(addressBookProvider.notifier).load();
    if (!mounted) return;

    context.go(RoutePaths.home);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(otpProvider(widget.phone));
    final controller = ref.read(otpProvider(widget.phone).notifier);

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppStrings.otpTitle, style: context.text.displaySmall),
              const SizedBox(height: AppSpacing.md),
              Text.rich(
                TextSpan(
                  text: 'We sent a code to ',
                  style: context.text.bodyLarge!
                      .copyWith(color: context.semantic.textSecondary),
                  children: [
                    TextSpan(
                      text: '+91 ${widget.phone}',
                      style: context.text.titleMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              OtpInput(
                hasError: state.hasError,
                onChanged: controller.setCode,
                onCompleted: (_) => _verify(),
              ),
              if (state.hasError) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 15,
                      color: context.colors.error,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        state.failure!.message,
                        style: context.text.bodySmall!
                            .copyWith(color: context.colors.error),
                      ),
                    ),
                  ],
                ),
              ],
              if (_debugOtp(state.debugOtp) != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: context.semantic.warningSoft,
                    borderRadius: AppRadii.rMd,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.science_outlined,
                        size: 16,
                        color: context.semantic.warning,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Test environment code: ${_debugOtp(state.debugOtp)}',
                          style: context.text.labelMedium!
                              .copyWith(color: context.semantic.warning),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'Verify & continue',
                isLoading: state.isVerifying,
                onPressed: state.canVerify ? _verify : null,
              ),
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: state.canResend
                    ? TextButton(
                        onPressed: controller.resend,
                        child: Text(
                          AppStrings.resendOtp,
                          style: context.text.labelLarge!
                              .copyWith(color: context.colors.primary),
                        ),
                      )
                    : Text(
                        'Resend code in ${state.secondsRemaining}s',
                        style: context.text.bodyMedium,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
