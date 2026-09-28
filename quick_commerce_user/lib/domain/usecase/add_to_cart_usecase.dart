import '../model/addon.dart';
import '../model/cart.dart';
import '../model/product.dart';
import '../model/product_variant.dart';
import '../repository/cart_repository.dart';
import '../service/cart_pricing_service.dart';
import '../service/stock_service.dart';

/// What the caller must do next after attempting an add.
sealed class AddToCartOutcome {
  const AddToCartOutcome();
}

class CartUpdated extends AddToCartOutcome {
  const CartUpdated(this.cart);
  final Cart cart;
}

/// The product has more than one variant — the UI must open the variant sheet.
class NeedsVariantSelection extends AddToCartOutcome {
  const NeedsVariantSelection(this.product);
  final Product product;
}

/// Adding would mix sellers; the UI must confirm clearing the cart.
class SellerConflict extends AddToCartOutcome {
  const SellerConflict(this.currentSellerName, this.product);
  final String currentSellerName;
  final Product product;
}

class AddRejected extends AddToCartOutcome {
  const AddRejected(this.reason);
  final String reason;
}

/// Adds a product to the cart, persists it, and mirrors it to the backend.
class AddToCartUseCase {
  const AddToCartUseCase({
    required CartRepository repository,
    required CartPricingService pricingService,
    required StockService stockService,
  })  : _repository = repository,
        _pricing = pricingService,
        _stock = stockService;

  final CartRepository _repository;
  final CartPricingService _pricing;
  final StockService _stock;

  Future<AddToCartOutcome> call(
    Cart cart, {
    required Product product,
    ProductVariant? variant,
    List<Addon> addons = const [],
    int quantity = 1,
    bool replaceSeller = false,
    bool skipVariantPrompt = false,
  }) async {
    if (!product.isPurchasable) {
      return const AddRejected('This item is out of stock');
    }
    if (!product.sellerAcceptingOrders) {
      return const AddRejected('This store is not accepting orders right now');
    }
    if (product.hasVariants && variant == null && !skipVariantPrompt) {
      return NeedsVariantSelection(product);
    }

    final conflict = _pricing.conflictWith(cart, product);
    if (conflict != null && !replaceSeller) {
      return SellerConflict(conflict, product);
    }

    final existing = cart.quantityOf(product.id);
    if (!_stock.canAdd(product, currentQuantity: existing, adding: quantity)) {
      return AddRejected(
        _stock.capReason(product, existing) ?? 'You have reached the limit',
      );
    }

    final updated = _pricing.addItem(
      cart,
      product: product,
      variant: variant,
      addons: addons,
      quantity: quantity,
      replaceSeller: replaceSeller,
    );

    await _persist(updated);
    return CartUpdated(updated);
  }

  Future<Cart> setQuantity(Cart cart, String lineId, int quantity) async {
    final updated = _pricing.setQuantity(cart, lineId, quantity);
    await _persist(updated);
    return updated;
  }

  Future<Cart> clear() async {
    await _persist(Cart.empty);
    return Cart.empty;
  }

  Future<void> _persist(Cart cart) async {
    await _repository.cache(cart);
    // Server mirroring is best-effort; a failure must not block the UI.
    unawaited(_repository.sync(cart));
  }

  static void unawaited(Future<void> future) {
    future.catchError((_) {});
  }
}
