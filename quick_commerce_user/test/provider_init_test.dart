import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_user/core/local_storage/local_storage.dart';
import 'package:quick_commerce_user/di/repository_providers.dart';
import 'package:quick_commerce_user/ui/screens/auth/otp/otp_provider.dart';

/// In-memory [LocalStorage] so providers can initialise without a platform
/// channel.
class _FakeStorage implements LocalStorage {
  final _values = <String, Object>{};

  @override
  bool? getBool(String key) => _values[key] as bool?;

  @override
  String? getString(String key) => _values[key] as String?;

  @override
  List<String> getStringList(String key) =>
      (_values[key] as List<String>?) ?? const [];

  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;

  @override
  Future<void> setString(String key, String value) async => _values[key] = value;

  @override
  Future<void> setStringList(String key, List<String> value) async =>
      _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}

/// A `Notifier` that reads or writes `state` inside `build()` throws
/// "Tried to read the state of an uninitialized provider" — at runtime, on the
/// device, with nothing in `flutter analyze` to warn you. Reading each provider
/// once here catches it in CI instead.
void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [localStorageProvider.overrideWithValue(_FakeStorage())],
    );
    addTearDown(container.dispose);
  });

  test('the OTP provider initialises and arms its resend countdown', () {
    final state = container.read(otpProvider('9876543210'));

    expect(state.secondsRemaining, 30);
    expect(state.canResend, isFalse);
    expect(state.code, isEmpty);
  });

  test('each OTP family key gets its own independent state', () {
    container.read(otpProvider('9000000001').notifier).setCode('12');
    final other = container.read(otpProvider('9000000002'));

    expect(container.read(otpProvider('9000000001')).code, '12');
    expect(other.code, isEmpty);
  });

  test('the countdown ticks down and stops at zero', () {
    FakeAsync().run((async) {
      final local = ProviderContainer(
        overrides: [localStorageProvider.overrideWithValue(_FakeStorage())],
      );
      addTearDown(local.dispose);

      local.read(otpProvider('9876543210'));
      async.elapse(const Duration(seconds: 3));
      expect(local.read(otpProvider('9876543210')).secondsRemaining, 27);

      // Past the window the timer cancels itself rather than running negative.
      async.elapse(const Duration(seconds: 60));
      expect(local.read(otpProvider('9876543210')).secondsRemaining, 0);
      expect(local.read(otpProvider('9876543210')).canResend, isTrue);
    });
  });
}
