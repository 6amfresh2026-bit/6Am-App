import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../di/app_providers.dart';
import '../../../../di/repository_providers.dart';
import '../../../common/widgets/buttons/primary_button.dart';
import '../../../common/widgets/feedback/app_toast.dart';
import '../../../common/widgets/inputs/app_text_field.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  String? _nameError;
  String? _emailError;
  String _gender = '';
  DateTime? _dateOfBirth;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _name = TextEditingController(text: user?.name ?? '');
    _email = TextEditingController(text: user?.email ?? '');
    _gender = user?.gender ?? '';
    _dateOfBirth = user?.dateOfBirth;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nameError = Validators.required(_name.text, 'Name');
    final emailError = Validators.email(_email.text);
    setState(() {
      _nameError = nameError;
      _emailError = emailError;
    });
    if (nameError != null || emailError != null) return;

    setState(() => _saving = true);
    try {
      final user = await ref.read(authRepositoryProvider).updateProfile(
            name: _name.text.trim(),
            email: _email.text.trim(),
            gender: _gender,
            dateOfBirth: _dateOfBirth,
          );
      ref.read(authProvider.notifier).setUser(user);
      if (!mounted) return;
      AppToast.success(context, 'Profile updated');
      context.pop();
    } catch (e) {
      // Surface what the server actually rejected — "email already in use" is
      // something the user can act on; "Could not save your profile" is not.
      if (mounted) AppToast.error(context, ErrorMapper.toFailure(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor:
                        context.colors.primary.withValues(alpha: 0.12),
                    child: Text(
                      (user?.displayName ?? 'S').initials,
                      style: context.text.displaySmall!
                          .copyWith(color: context.colors.primary),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      // Image upload needs a file picker, which is out of scope
                      // for this build — see README → Backend Gaps.
                      onTap: () => AppToast.show(
                        context,
                        'Photo uploads are coming soon',
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: context.colors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: context.colors.surface, width: 2),
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          size: 15,
                          color: context.colors.surface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppTextField(
              controller: _name,
              label: 'Full name',
              hint: 'How should we address you?',
              errorText: _nameError,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _email,
              label: 'Email',
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              errorText: _emailError,
              textCapitalization: TextCapitalization.none,
            ),
            const SizedBox(height: AppSpacing.lg),
            _ReadOnlyField(
              label: 'Mobile number',
              value: user?.maskedPhone ?? '',
              note: 'Your number is verified and cannot be changed here',
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Gender', style: context.text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: const [
                ('male', 'Male'),
                ('female', 'Female'),
                ('other', 'Other'),
                ('prefer-not-to-say', 'Prefer not to say'),
              ]
                  .map(
                    (option) => ChoiceChip(
                      label: Text(option.$2),
                      selected: _gender == option.$1,
                      onSelected: (_) => setState(() => _gender = option.$1),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.cake_outlined,
                color: context.semantic.textSecondary,
              ),
              title: Text(
                _dateOfBirth == null
                    ? 'Add your birthday'
                    : '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
                style: context.text.bodyLarge,
              ),
              subtitle: Text(
                'We send a small treat on the day',
                style: context.text.bodySmall,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dateOfBirth ?? DateTime(now.year - 25),
                  firstDate: DateTime(now.year - 100),
                  lastDate: now,
                );
                if (picked != null) setState(() => _dateOfBirth = picked);
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'Save changes',
              isLoading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.note,
  });

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.text.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: context.semantic.surfaceAlt,
            borderRadius: AppRadii.rMd,
            border: Border.all(color: context.semantic.border),
          ),
          child: Row(
            children: [
              Expanded(child: Text(value, style: context.text.bodyLarge)),
              Icon(
                Icons.verified_rounded,
                size: 17,
                color: context.semantic.success,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(note, style: context.text.bodySmall),
      ],
    );
  }
}
