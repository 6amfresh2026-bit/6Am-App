/// Payment options. The wire values are exactly what the backend accepts on
/// `POST /orders` (`razorpay | razorpay_qr | card | wallet | cash`).
enum PaymentMethod {
  upi('razorpay', 'UPI', 'Pay via any UPI app'),
  card('card', 'Credit / Debit card', 'Visa, Mastercard, RuPay'),
  qr('razorpay_qr', 'Scan & Pay', 'Show a QR to complete payment'),
  wallet('wallet', 'Suvio Wallet', 'Use your wallet balance'),
  cash('cash', 'Cash on Delivery', 'Pay the rider when it arrives');

  const PaymentMethod(this.wireValue, this.label, this.subtitle);

  final String wireValue;
  final String label;
  final String subtitle;

  bool get isOnline => this != PaymentMethod.cash && this != PaymentMethod.wallet;

  /// What `POST /orders` is told.
  ///
  /// `razorpay_qr` is accepted by the validator but the order service neither
  /// creates a Razorpay order for it nor holds it as awaiting payment — the
  /// order would be placed and never charged. Sending `razorpay` instead keeps
  /// the scan-and-pay option working, with the QR shown inside the Razorpay
  /// sheet via the `upi` method hint below. (`card` the backend already
  /// rewrites to `razorpay` itself.)
  String get orderWireValue =>
      this == PaymentMethod.qr ? 'razorpay' : wireValue;

  /// Preselects a tab in the Razorpay sheet. Empty means "show them all".
  String get razorpayMethod => switch (this) {
        PaymentMethod.upi || PaymentMethod.qr => 'upi',
        PaymentMethod.card => 'card',
        PaymentMethod.wallet || PaymentMethod.cash => '',
      };

  static PaymentMethod fromWire(String? value) => PaymentMethod.values.firstWhere(
        (m) => m.wireValue == value,
        orElse: () => PaymentMethod.upi,
      );
}
