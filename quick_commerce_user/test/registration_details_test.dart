import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_user/domain/model/user.dart';
import 'package:quick_commerce_user/ui/screens/auth/register/register_state.dart';

/// Sign-in is by phone alone, so the account is created before anyone says who
/// they are. These are the two rules that decide whether we still have to ask.
void main() {
  User user({String name = '', String email = ''}) =>
      User(id: 'u1', phone: '9876543210', name: name, email: email);

  group('who still owes us details', () {
    test('a number with nothing attached does', () {
      expect(user().needsRegistrationDetails, isTrue);
    });

    test('whitespace is not a name', () {
      expect(user(name: '   ').needsRegistrationDetails, isTrue);
    });

    test('a named account does not', () {
      expect(user(name: 'Rishi').needsRegistrationDetails, isFalse);
    });

    test('an older account with no email is left alone', () {
      // It matches the server's own `isNewUser` test, which reads the name
      // only. Gating on email too would drag long-standing customers back
      // through sign-up on their next launch.
      expect(user(name: 'Rishi').needsRegistrationDetails, isFalse);
    });
  });

  group('the form itself asks for both', () {
    test('an empty form is not submittable', () {
      const state = RegisterState();
      expect(state.isValid, isFalse);
      expect(state.nameError, isNotNull);
      expect(state.emailError, isNotNull);
    });

    test('a name alone is not enough — email is required here', () {
      const state = RegisterState(name: 'Rishi');
      expect(state.isValid, isFalse);
      expect(state.emailError, 'Email is required');
    });

    test('a malformed email is refused before the request goes out', () {
      const state = RegisterState(name: 'Rishi', email: 'rishi@gmail');
      expect(state.isValid, isFalse);
      expect(state.emailError, 'Enter a valid email');
    });

    test('both filled in is valid', () {
      const state = RegisterState(name: 'Rishi', email: 'rishi@gmail.com');
      expect(state.isValid, isTrue);
    });

    test('errors stay quiet until the first submit', () {
      const untouched = RegisterState();
      expect(untouched.visibleNameError, isNull);
      expect(untouched.visibleEmailError, isNull);

      final submitted = untouched.copyWith(showErrors: true);
      expect(submitted.visibleNameError, isNotNull);
      expect(submitted.visibleEmailError, isNotNull);
    });
  });
}
