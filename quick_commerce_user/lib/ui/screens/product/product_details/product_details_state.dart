import '../../../../core/errors/failure.dart';
import '../../../../domain/model/addon.dart';
import '../../../../domain/model/product.dart';
import '../../../../domain/model/product_variant.dart';
import '../../../../domain/model/review.dart';

class ProductDetailsState {
  const ProductDetailsState({
    this.product,
    this.selectedVariant,
    this.selectedAddons = const [],
    this.addonGroups = const [],
    this.related = const [],
    this.reviews = const [],
    this.ratingSummary = RatingSummary.empty,
    this.rateableOrders = const [],
    this.quantity = 1,
    this.isLoading = true,
    this.isLoadingExtras = true,
    this.failure,
  });

  final Product? product;
  final ProductVariant? selectedVariant;
  final List<Addon> selectedAddons;
  final List<AddonGroup> addonGroups;
  final List<Product> related;
  final List<Review> reviews;
  final RatingSummary ratingSummary;

  /// Delivered orders containing this product that the user has not yet rated.
  final List<({String orderId, String displayId, DateTime placedAt})> rateableOrders;

  final int quantity;
  final bool isLoading;
  final bool isLoadingExtras;
  final Failure? failure;

  /// Price for the current variant selection, times quantity, plus add-ons.
  double get effectiveUnitPrice =>
      (selectedVariant?.price ?? product?.price ?? 0) +
      selectedAddons.fold<double>(0, (sum, a) => sum + a.price);

  double get totalPrice => effectiveUnitPrice * quantity;

  double? get effectiveStrikePrice {
    final variant = selectedVariant;
    if (variant != null) return variant.isDiscounted ? variant.comparePrice : null;
    return product?.strikePrice;
  }

  bool get canRate => rateableOrders.isNotEmpty;

  ProductDetailsState copyWith({
    Product? product,
    ProductVariant? selectedVariant,
    List<Addon>? selectedAddons,
    List<AddonGroup>? addonGroups,
    List<Product>? related,
    List<Review>? reviews,
    RatingSummary? ratingSummary,
    List<({String orderId, String displayId, DateTime placedAt})>? rateableOrders,
    int? quantity,
    bool? isLoading,
    bool? isLoadingExtras,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      ProductDetailsState(
        product: product ?? this.product,
        selectedVariant: selectedVariant ?? this.selectedVariant,
        selectedAddons: selectedAddons ?? this.selectedAddons,
        addonGroups: addonGroups ?? this.addonGroups,
        related: related ?? this.related,
        reviews: reviews ?? this.reviews,
        ratingSummary: ratingSummary ?? this.ratingSummary,
        rateableOrders: rateableOrders ?? this.rateableOrders,
        quantity: quantity ?? this.quantity,
        isLoading: isLoading ?? this.isLoading,
        isLoadingExtras: isLoadingExtras ?? this.isLoadingExtras,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}
