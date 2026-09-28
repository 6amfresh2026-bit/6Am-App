import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Why an order just left the rider's list.
///
/// An order can be taken away for three different reasons — the accept window
/// lapsed, the customer cancelled, or the shop never answered and it was
/// auto-cancelled. Before this the order simply vanished, or worse did not,
/// and the rider turned up at a shop for something that no longer existed.
///
/// Held as state rather than shown from the controller because the controller
/// has no `BuildContext`; whichever screen is on top reads this and says it.
class OrderRemovedNoticeController extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String reason) => state = reason;

  /// Called once the message has been displayed, so it cannot fire again on
  /// the next rebuild or when the rider navigates back.
  void clear() => state = null;
}

final orderRemovedNoticeProvider =
    NotifierProvider<OrderRemovedNoticeController, String?>(
  OrderRemovedNoticeController.new,
);
