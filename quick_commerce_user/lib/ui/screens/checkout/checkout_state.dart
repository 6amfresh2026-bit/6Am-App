import '../../../core/errors/failure.dart';
import '../../../domain/model/payment_method.dart';
import '../../../domain/service/checkout_validation_service.dart';

class CheckoutState {
  const CheckoutState({
    this.paymentMethod = PaymentMethod.upi,
    this.instructions = '',
    this.sendCutlery = false,
    this.allowSubstitutes = false,
    this.expandedSummary = false,
    this.isPlacing = false,
    this.issues = const [],
    this.failure,
    this.shakeAddressCard = false,
  });

  final PaymentMethod paymentMethod;
  final String instructions;
  final bool sendCutlery;

  /// Whether the shop may swap an item it cannot supply.
  ///
  /// Defaults to **off**: swapping spends the customer's money on something
  /// they did not choose, and the lactose-free shopper handed ordinary milk
  /// has been sold the one thing they were avoiding.
  final bool allowSubstitutes;
  final bool expandedSummary;
  final bool isPlacing;

  /// Blocking problems surfaced after a failed "proceed" attempt.
  final List<CheckoutIssue> issues;
  final Failure? failure;

  /// Set for one frame to trigger the address card's shake animation.
  final bool shakeAddressCard;

  CheckoutState copyWith({
    PaymentMethod? paymentMethod,
    String? instructions,
    bool? sendCutlery,
    bool? allowSubstitutes,
    bool? expandedSummary,
    bool? isPlacing,
    List<CheckoutIssue>? issues,
    Failure? failure,
    bool? shakeAddressCard,
    bool clearFailure = false,
  }) =>
      CheckoutState(
        paymentMethod: paymentMethod ?? this.paymentMethod,
        instructions: instructions ?? this.instructions,
        sendCutlery: sendCutlery ?? this.sendCutlery,
        allowSubstitutes: allowSubstitutes ?? this.allowSubstitutes,
        expandedSummary: expandedSummary ?? this.expandedSummary,
        isPlacing: isPlacing ?? this.isPlacing,
        issues: issues ?? this.issues,
        failure: clearFailure ? null : (failure ?? this.failure),
        shakeAddressCard: shakeAddressCard ?? this.shakeAddressCard,
      );
}
