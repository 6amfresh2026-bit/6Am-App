import '../../../../core/errors/failure.dart';
import '../../../../core/utils/validators.dart';

/// The one form between a verified phone number and a usable account.
class RegisterState {
  const RegisterState({
    this.name = '',
    this.email = '',
    this.isSubmitting = false,
    this.showErrors = false,
    this.failure,
  });

  final String name;
  final String email;
  final bool isSubmitting;

  /// Errors stay hidden until the first submit, so an empty form does not
  /// greet a brand new customer with two red lines.
  final bool showErrors;

  final Failure? failure;

  /// Both are asked for, so neither may be skipped — an optional email here
  /// would be left blank by nearly everyone and the account would carry no
  /// way to reach them.
  String? get nameError => Validators.required(name, 'Name');
  String? get emailError => Validators.email(email, optional: false);

  String? get visibleNameError => showErrors ? nameError : null;
  String? get visibleEmailError => showErrors ? emailError : null;

  bool get isValid => nameError == null && emailError == null;
  bool get canSubmit => !isSubmitting;

  RegisterState copyWith({
    String? name,
    String? email,
    bool? isSubmitting,
    bool? showErrors,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      RegisterState(
        name: name ?? this.name,
        email: email ?? this.email,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        showErrors: showErrors ?? this.showErrors,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}
