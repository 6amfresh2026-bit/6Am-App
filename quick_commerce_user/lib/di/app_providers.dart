import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/error_mapper.dart';
import '../core/errors/failure.dart';
import '../core/local_storage/local_storage.dart';
import '../domain/model/address.dart';
import '../domain/model/addon.dart';
import '../domain/model/cart.dart';
import '../domain/model/coupon.dart';
import '../domain/model/product.dart';
import '../domain/model/wishlist.dart';
import '../domain/model/product_variant.dart';
import '../domain/model/user.dart';
import '../domain/usecase/add_to_cart_usecase.dart';
import '../domain/usecase/apply_coupon_usecase.dart';
import 'repository_providers.dart';
import 'usecase_providers.dart';

// ── Connectivity ────────────────────────────────────────────────────────────

/// Online/offline, used to show the offline banner and gate network actions.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  final initial = await connectivity.checkConnectivity();
  yield _isOnline(initial);
  yield* connectivity.onConnectivityChanged.map(_isOnline);
});

bool _isOnline(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);

final isOfflineProvider = Provider<bool>(
  (ref) => ref.watch(connectivityProvider).valueOrNull == false,
);

// ── Auth ────────────────────────────────────────────────────────────────────

class AuthState {
  const AuthState({this.user, this.isLoading = false});

  final User? user;
  final bool isLoading;

  bool get isSignedIn => user != null;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final repository = ref.read(authRepositoryProvider);
    // Render a signed-in shell immediately from cache, then refresh from /me.
    if (repository.isSignedIn) {
      scheduleMicrotask(refresh);
      // FCM rotates tokens between launches; re-sync so the backend can still
      // reach this device. No-op when the token has not changed.
      scheduleMicrotask(ref.read(notificationServiceProvider).registerDevice);
      return AuthState(user: repository.cachedUser);
    }
    return const AuthState();
  }

  Future<void> refresh() async {
    final repository = ref.read(authRepositoryProvider);
    if (!repository.isSignedIn) {
      state = const AuthState();
      return;
    }
    try {
      state = AuthState(user: await repository.currentUser());
    } catch (_) {
      // A failed refresh keeps the cached user; the interceptor already tried
      // to renew the token and will sign the user out if it could not.
      state = AuthState(user: repository.cachedUser);
    }
  }

  void setUser(User user) => state = AuthState(user: user);

  Future<void> signOut() async {
    state = const AuthState(isLoading: true);
    await ref.read(authRepositoryProvider).signOut();
    ref.read(cartProvider.notifier).clearLocal();
    ref.invalidate(wishlistProvider);
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

// ── Selected delivery address ───────────────────────────────────────────────

class AddressBookState {
  const AddressBookState({
    this.addresses = const [],
    this.selectedId,
    this.isLoading = false,
    this.failure,
  });

  final List<Address> addresses;
  final String? selectedId;
  final bool isLoading;
  final Failure? failure;

  Address? get selected {
    if (addresses.isEmpty) return null;
    for (final a in addresses) {
      if (a.id == selectedId) return a;
    }
    return addresses.first;
  }

  AddressBookState copyWith({
    List<Address>? addresses,
    String? selectedId,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      AddressBookState(
        addresses: addresses ?? this.addresses,
        selectedId: selectedId ?? this.selectedId,
        isLoading: isLoading ?? this.isLoading,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

class AddressBookController extends Notifier<AddressBookState> {
  @override
  AddressBookState build() {
    final signedIn = ref.watch(authProvider).isSignedIn;
    if (signedIn) scheduleMicrotask(load);
    return AddressBookState(
      selectedId:
          ref.read(localStorageProvider).getString(StorageKeys.selectedAddressId),
    );
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      final addresses = await ref.read(addressRepositoryProvider).list();
      String selectedId = state.selectedId ?? '';
      if ((selectedId.isEmpty || !addresses.any((a) => a.id == selectedId)) &&
          addresses.isNotEmpty) {
        final def =
            addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);
        selectedId = def.id;
      }
      state = state.copyWith(
        addresses: addresses,
        selectedId: selectedId,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, failure: ErrorMapper.toFailure(e));
    }
  }

  Future<void> select(String addressId) async {
    state = state.copyWith(selectedId: addressId);
    await ref
        .read(localStorageProvider)
        .setString(StorageKeys.selectedAddressId, addressId);
  }

  Future<Address> add(Address address) async {
    final saved = await ref.read(addressRepositoryProvider).add(address);
    await load();
    await select(saved.id);
    return saved;
  }

  Future<Address> update(Address address) async {
    final saved = await ref.read(addressRepositoryProvider).update(address);
    await load();
    return saved;
  }

  Future<void> remove(String addressId) async {
    await ref.read(addressRepositoryProvider).delete(addressId);
    if (state.selectedId == addressId) {
      state = state.copyWith(selectedId: '');
    }
    await load();
  }

  Future<void> makeDefault(String addressId) async {
    await ref.read(addressRepositoryProvider).setDefault(addressId);
    await load();
  }
}

final addressBookProvider =
    NotifierProvider<AddressBookController, AddressBookState>(
  AddressBookController.new,
);

/// Convenience for the many screens that only need the chosen address.
final selectedAddressProvider =
    Provider<Address?>((ref) => ref.watch(addressBookProvider).selected);

// ── Cart (global: the badge is visible on every tab) ────────────────────────

class CartState {
  const CartState({
    this.cart = Cart.empty,
    this.isPricing = false,
    this.failure,
    this.lastAddedProductId,
  });

  final Cart cart;
  final bool isPricing;
  final Failure? failure;

  /// Drives the fly-to-cart confirmation animation.
  final String? lastAddedProductId;

  CartState copyWith({
    Cart? cart,
    bool? isPricing,
    Failure? failure,
    String? lastAddedProductId,
    bool clearFailure = false,
  }) =>
      CartState(
        cart: cart ?? this.cart,
        isPricing: isPricing ?? this.isPricing,
        failure: clearFailure ? null : (failure ?? this.failure),
        lastAddedProductId: lastAddedProductId ?? this.lastAddedProductId,
      );
}

class CartController extends Notifier<CartState> {
  Timer? _priceDebounce;

  @override
  CartState build() {
    scheduleMicrotask(_restore);
    ref.onDispose(() => _priceDebounce?.cancel());
    return const CartState();
  }

  Future<void> _restore() async {
    final cached = await ref.read(cartRepositoryProvider).loadCached();
    if (cached.isNotEmpty) {
      state = state.copyWith(cart: cached);
      schedulePricing();
    }
  }

  Future<AddToCartOutcome> add(
    Product product, {
    ProductVariant? variant,
    List<Addon> addons = const [],
    int quantity = 1,
    bool replaceSeller = false,
    bool skipVariantPrompt = false,
  }) async {
    final outcome = await ref.read(addToCartUseCaseProvider)(
      state.cart,
      product: product,
      variant: variant,
      addons: addons,
      quantity: quantity,
      replaceSeller: replaceSeller,
      skipVariantPrompt: skipVariantPrompt,
    );

    if (outcome is CartUpdated) {
      state = state.copyWith(
        cart: outcome.cart,
        lastAddedProductId: product.id,
        clearFailure: true,
      );
      schedulePricing();
    }
    return outcome;
  }

  Future<void> setQuantity(String lineId, int quantity) async {
    final cart = await ref
        .read(addToCartUseCaseProvider)
        .setQuantity(state.cart, lineId, quantity);
    state = state.copyWith(cart: cart, clearFailure: true);
    schedulePricing();
  }

  Future<void> increment(String lineId) async {
    final line = state.cart.lineById(lineId);
    if (line == null) return;
    await setQuantity(lineId, line.quantity + 1);
  }

  Future<void> decrement(String lineId) async {
    final line = state.cart.lineById(lineId);
    if (line == null) return;
    await setQuantity(lineId, line.quantity - 1);
  }

  Future<void> removeLine(String lineId) => setQuantity(lineId, 0);

  Future<void> clear() async {
    await ref.read(addToCartUseCaseProvider).clear();
    state = const CartState();
  }

  /// Drops the in-memory cart without touching the server (used on sign-out).
  void clearLocal() => state = const CartState();

  Future<void> setDeliveryMode(String mode) async {
    state = state.copyWith(cart: state.cart.copyWith(deliveryMode: mode));
    await priceNow();
  }

  /// Coalesces the rapid stepper taps that would otherwise fire a pricing call
  /// per tap.
  void schedulePricing() {
    _priceDebounce?.cancel();
    if (state.cart.isEmpty) return;
    _priceDebounce = Timer(const Duration(milliseconds: 450), priceNow);
  }

  Future<void> priceNow() async {
    if (state.cart.isEmpty) return;
    if (!ref.read(authProvider).isSignedIn) return;

    state = state.copyWith(isPricing: true, clearFailure: true);
    try {
      final priced = await ref.read(priceCartUseCaseProvider)(
        state.cart,
        address: ref.read(selectedAddressProvider),
      );
      state = state.copyWith(cart: priced, isPricing: false);
    } catch (e) {
      state = state.copyWith(isPricing: false, failure: ErrorMapper.toFailure(e));
    }
  }

  Future<CouponOutcome> applyCoupon(Coupon coupon) async {
    state = state.copyWith(isPricing: true, clearFailure: true);
    try {
      final outcome = await ref.read(applyCouponUseCaseProvider)(
        state.cart,
        coupon,
        address: ref.read(selectedAddressProvider),
      );
      if (outcome is CouponApplied) {
        state = state.copyWith(cart: outcome.cart, isPricing: false);
      } else {
        state = state.copyWith(isPricing: false);
      }
      return outcome;
    } catch (e) {
      state = state.copyWith(isPricing: false, failure: ErrorMapper.toFailure(e));
      return CouponRejected(ErrorMapper.toFailure(e).message);
    }
  }

  Future<void> removeCoupon() async {
    state = state.copyWith(isPricing: true);
    try {
      final cart = await ref.read(applyCouponUseCaseProvider).remove(
            state.cart,
            address: ref.read(selectedAddressProvider),
          );
      state = state.copyWith(cart: cart, isPricing: false);
    } catch (e) {
      state = state.copyWith(isPricing: false, failure: ErrorMapper.toFailure(e));
    }
  }
}

final cartProvider = NotifierProvider<CartController, CartState>(CartController.new);

/// Scoped so the badge does not rebuild whole screens.
final cartItemCountProvider =
    Provider<int>((ref) => ref.watch(cartProvider.select((s) => s.cart.itemCount)));

// ── Wishlist ────────────────────────────────────────────────────────────────

/// Holds the whole wishlist — saved products and saved stores — from a single
/// fetch, so every heart in the app and both wishlist tabs read one source.
class WishlistController extends AsyncNotifier<Wishlist> {
  @override
  Future<Wishlist> build() async {
    if (!ref.watch(authProvider).isSignedIn) return Wishlist.empty;
    return ref.read(wishlistRepositoryProvider).snapshot();
  }

  /// Re-reads the whole list from the server.
  ///
  /// Hearts stay correct locally after a toggle, but a *saved* product only
  /// gains its card here: the toggle response carries no catalogue fields, so
  /// the wishlist screen would otherwise show a heart with nothing behind it
  /// until the app was restarted.
  Future<void> refresh() async {
    if (!ref.read(authProvider).isSignedIn) {
      state = const AsyncData(Wishlist.empty);
      return;
    }
    try {
      state = AsyncData(await ref.read(wishlistRepositoryProvider).snapshot());
    } catch (_) {
      // Keep whatever is already on screen; a failed refresh must not empty a
      // list the customer can still read.
    }
  }

  Future<void> toggle(String productId) => _toggle(
        isSaved: (w) => w.hasProduct(productId),
        apply: (w, saved) => w.withProduct(productId, saved: saved),
        write: (saved) => ref
            .read(wishlistRepositoryProvider)
            .setProductSaved(productId, saved: saved),
      );

  Future<void> toggleStore(String storeId) => _toggle(
        isSaved: (w) => w.hasStore(storeId),
        apply: (w, saved) => w.withStore(storeId, saved: saved),
        write: (saved) => ref
            .read(wishlistRepositoryProvider)
            .setStoreSaved(storeId, saved: saved),
      );

  /// Optimistic in both directions: the heart flips instantly and rolls back
  /// only if the write fails. Safe because both writes are idempotent, so a
  /// retry cannot double-add and taps need no serialising.
  Future<void> _toggle({
    required bool Function(Wishlist) isSaved,
    required Wishlist Function(Wishlist, bool) apply,
    required Future<bool> Function(bool) write,
  }) async {
    final current = state.valueOrNull ?? Wishlist.empty;
    final wanted = !isSaved(current);
    state = AsyncData(apply(current, wanted));

    try {
      // Trust the server's answer over what we assumed, in case the two ever
      // disagree — it is the authority on what is saved.
      final confirmed = await write(wanted);
      state = AsyncData(apply(current, confirmed));
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  bool contains(String productId) =>
      state.valueOrNull?.hasProduct(productId) ?? false;

  bool containsStore(String storeId) =>
      state.valueOrNull?.hasStore(storeId) ?? false;
}

final wishlistProvider =
    AsyncNotifierProvider<WishlistController, Wishlist>(WishlistController.new);

final isWishlistedProvider = Provider.family<bool, String>(
  (ref, productId) =>
      ref.watch(wishlistProvider).valueOrNull?.hasProduct(productId) ?? false,
);

final isStoreSavedProvider = Provider.family<bool, String>(
  (ref, storeId) =>
      ref.watch(wishlistProvider).valueOrNull?.hasStore(storeId) ?? false,
);
