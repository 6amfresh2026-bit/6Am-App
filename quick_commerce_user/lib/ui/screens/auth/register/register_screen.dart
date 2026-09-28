import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../di/app_providers.dart';
import '../../../../navigation/route_paths.dart';
import '../../../common/widgets/buttons/primary_button.dart';
import '../../../common/widgets/inputs/app_text_field.dart';
import 'register_provider.dart';

/// Second half of sign-up, shown once the phone number is verified and the
/// account turns out to be new.
///
/// There is no way back and no skip: an account with no name shows up as
/// "Suvio customer" to the rider, on the invoice and in support, and with no
/// email there is nowhere to send an order receipt. Leaving it until later
/// means never.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  late final TextEditingController _name;
  late final TextEditingController _email;

  @override
  void initState() {
    super.initState();
    final state = ref.read(registerProvider);
    _name = TextEditingController(text: state.name);
    _email = TextEditingController(text: state.email);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final saved = await ref.read(registerProvider.notifier).submit();
    if (!saved || !mounted) return;

    // Same landing as a returning sign-in: Home raises the location prompt
    // over itself when there is no address yet.
    await ref.read(addressBookProvider.notifier).load();
    if (!mounted) return;

    context.go(RoutePaths.home);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerProvider);
    final controller = ref.read(registerProvider.notifier);
    final phone = ref.watch(authProvider).user?.maskedPhone ?? '';

    return PopScope(
      // The OTP behind this screen is already spent; going back would land on
      // a code that can no longer be verified.
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xl),
                Text(AppStrings.registerTitle, style: context.text.displaySmall),
                const SizedBox(height: AppSpacing.md),
                Text(
                  AppStrings.registerSubtitle,
                  style: context.text.bodyLarge!
                      .copyWith(color: context.semantic.textSecondary),
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: context.semantic.success,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '$phone verified',
                        style: context.text.labelLarge!
                            .copyWith(color: context.semantic.success),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                AppTextField(
                  controller: _name,
                  label: 'Full name',
                  hint: 'How should we address you?',
                  autofocus: true,
                  errorText: state.visibleNameError,
                  textCapitalization: TextCapitalization.words,
                  onChanged: controller.setName,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _email,
                  label: 'Email',
                  hint: 'you@gmail.com',
                  keyboardType: TextInputType.emailAddress,
                  errorText: state.visibleEmailError,
                  textCapitalization: TextCapitalization.none,
                  onChanged: controller.setEmail,
                  onSubmitted: (_) => _submit(),
                ),
                if (state.failure != null) ...[
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
                const SizedBox(height: AppSpacing.md),
                Text(
                  AppStrings.registerEmailNote,
                  style: context.text.bodySmall!
                      .copyWith(color: context.semantic.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Continue',
                  isLoading: state.isSubmitting,
                  onPressed: state.canSubmit ? _submit : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
