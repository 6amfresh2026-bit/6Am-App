import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_user/ui/screens/location/location_prompt/location_prompt_sheet.dart';

/// "Where should we deliver?" is a first-sign-in prompt, not a recurring one.
/// Once a customer has been asked, it must never reappear on its own — whether
/// or not they actually added an address.
void main() {
  bool prompt({
    String userId = 'u1',
    List<String> alreadyPrompted = const [],
    bool hasSavedAddress = false,
  }) =>
      LocationPromptSheet.shouldPrompt(
        userId: userId,
        alreadyPrompted: alreadyPrompted,
        hasSavedAddress: hasSavedAddress,
      );

  test('a brand-new customer is asked', () {
    expect(prompt(), isTrue);
  });

  test('the same customer is never asked twice', () {
    // The whole point of this change: dismissing it is an answer, and the app
    // must not nag on every launch.
    expect(prompt(alreadyPrompted: ['u1']), isFalse);
  });

  test('still not asked again even with no address saved', () {
    // They said "later". Checkout will ask when it actually matters.
    expect(prompt(alreadyPrompted: ['u1'], hasSavedAddress: false), isFalse);
  });

  test('a customer who already has an address is never asked', () {
    expect(prompt(hasSavedAddress: true), isFalse);
  });

  test('a second account on the same device is asked on its own merits', () {
    // Keyed by user, not by device — handing the phone to someone else, or
    // signing in with a different number, still gets the prompt once.
    expect(prompt(userId: 'u2', alreadyPrompted: ['u1']), isTrue);
  });

  test('a signed-out session is never prompted', () {
    expect(prompt(userId: ''), isFalse);
  });
}
