import '../../core/extensions/num_extensions.dart';
import '../model/addon.dart';
import '../model/cart.dart';
import '../model/cart_item.dart';
import '../model/product.dart';
import '../model/product_variant.dart';

/// One row of the bill breakdown, ready to render.
class BillLine {
  const BillLine({
    required this.label,
    required this.amount,
    this.isDiscount = false,
    this.isFree = false,
    this.isTotal = false,
    this.note = '',
  });

  final String label;
  final double amount;
  final bool isDiscount;
  final bool isFree;
  final bool isTotal;
  final String note;
}

/// All cart mutation and bill *presentation* logic. Pure Dart.
///
/// The monetary figures themselves are owned by the server: this service never
/// invents a fee or a tax, it only arranges what `POST /orders/calculate`
/// returned and computes the local, pre-pricing optimistic values.
class CartPricingService {
  const CartPricingService({this.freeDeliveryThreshold = 199});

  /// Order value above which delivery is free. Sourced from the backend's
  /// public fee settings; the constructor default is only a cold-start guess.
  final double freeDeliveryThreshold;

  /// Adds [product] to [cart], merging into an identical existing line.
  ///
  /// Returns the original cart unchanged when the product is out of stock, and
  /// replaces the cart entirely when it comes from a different seller (the
  /// caller confirms that with the user first — see [conflictWith]).
  Cart addItem(
    Cart cart, {
    required Product product,
    ProductVariant? variant,
    List<Addon> addons = const [],
    int quantity = 1,
    bool replaceSeller = false,
  }) {
    if (!product.isPurchasable || quantity <= 0) return cart;

    final base = cart.conflictsWith(product)
        ? (replaceSeller ? Cart.empty : cart)
        : cart;
    if (base == cart && cart.conflictsWith(product)) return cart;

    final candidate = CartItem(
      product: product,
      quantity: quantity,
      variant: variant,
      addons: addons,
    );

    final items = [...base.items];
    final index = items.indexWhere((i) => i.lineId == candidate.lineId);
    if (index >= 0) {
      final merged = _clampQuantity(items[index], items[index].quantity + quantity);
      items[index] = merged;
    } else {
      items.add(_clampQuantity(candidate, quantity));
    }

    return base.copyWith(
      items: items,
      sellerId: product.sellerId,
      sellerName: product.sellerName,
      // Any change invalidates the server bill until it is re-priced.
      pricing: CartPricing.empty,
      priceChanges: const [],
    );
  }

  /// Sets an absolute quantity on a line; zero or less removes it.
  Cart setQuantity(Cart cart, String lineId, int quantity) {
    final items = [...cart.items];
    final index = items.indexWhere((i) => i.lineId == lineId);
    if (index < 0) return cart;

    if (quantity <= 0) {
      items.removeAt(index);
    } else {
      items[index] = _clampQuantity(items[index], quantity);
    }

    if (items.isEmpty) return Cart.empty;
    return cart.copyWith(
      items: items,
      pricing: CartPricing.empty,
      priceChanges: const [],
    );
  }

  Cart increment(Cart cart, String lineId) {
    final line = cart.lineById(lineId);
    if (line == null) return cart;
    return setQuantity(cart, lineId, line.quantity + 1);
  }

  Cart decrement(Cart cart, String lineId) {
    final line = cart.lineById(lineId);
    if (line == null) return cart;
    return setQuantity(cart, lineId, line.quantity - 1);
  }

  Cart removeLine(Cart cart, String lineId) => setQuantity(cart, lineId, 0);

  Cart clear(Cart cart) => Cart.empty;

  /// Name of the seller already in the cart when [product] belongs elsewhere.
  String? conflictWith(Cart cart, Product product) =>
      cart.conflictsWith(product) ? cart.sellerName : null;

  CartItem _clampQuantity(CartItem item, int desired) {
    final max = item.product.maxOrderableQty;
    return item.copyWith(quantity: desired > max ? max : desired);
  }

  /// How much more the customer must add to unlock free delivery.
  /// Returns 0 once the threshold is met (or when the bill already shows free).
  ///
  /// The server now computes this and sends it as `spendMoreForFreeDelivery`,
  /// which is authoritative: it knows the configured threshold, whether the
  /// feature is switched on at all, and what this basket actually subtotals.
  /// The local estimate below is only a stand-in until the quote lands, so the
  /// nudge does not pop in late with a different number.
  double amountToFreeDelivery(Cart cart) {
    if (cart.isEmpty) return 0;

    final priced = cart.pricing.total > 0;
    if (priced) return cart.pricing.spendMoreForFreeDelivery;

    if (cart.pricing.isFreeDelivery && priced) return 0;
    final gap = freeDeliveryThreshold - cart.provisionalSubtotal;
    return gap > 0 ? gap : 0;
  }

  /// The itemised bill. Falls back to the provisional subtotal so the cart can
  /// render something sensible while the pricing call is still in flight.
  List<BillLine> billLines(Cart cart) {
    final p = cart.pricing;
    final priced = p.total > 0;
    final subtotal = priced ? p.subtotal : cart.provisionalSubtotal;

    return [
      BillLine(label: 'Item total', amount: subtotal),
      if (cart.provisionalSavings > 0)
        BillLine(
          label: 'Item savings',
          amount: cart.provisionalSavings,
          isDiscount: true,
        ),
      BillLine(
        label: 'Delivery charge',
        amount: p.deliveryFee + p.deliveryFeeGst,
        isFree: priced && p.deliveryFee <= 0,
        note: p.deliveryFeeMessage,
      ),
      if (p.quickDeliveryFee > 0)
        BillLine(label: 'Priority delivery', amount: p.quickDeliveryFee),
      // Its own line, never folded into the platform fee: a surcharge the
      // customer can remove by adding one more item is worth naming, and
      // saying which basket size it applies below is what makes it actionable.
      if (p.hasSmallCartFee)
        BillLine(
          label: 'Small cart fee',
          amount: p.smallCartFee,
          note: p.smallCartThreshold > 0
              ? 'On orders under ${p.smallCartThreshold.asCurrency}'
              : '',
        ),
      if (p.packagingFee > 0)
        BillLine(label: 'Packaging', amount: p.packagingFee),
      BillLine(label: 'Platform fee', amount: p.platformFee),
      BillLine(label: 'Taxes & GST', amount: p.tax),
      if (p.discount > 0)
        BillLine(
          // Named from the applied coupon, not the attempted one.
          label: 'Coupon ${p.appliedCouponCode ?? 'discount'}',
          amount: p.discount,
          isDiscount: true,
        ),
      BillLine(
        label: 'To pay',
        amount: priced ? p.total : subtotal,
        isTotal: true,
      ),
    ];
  }
}
